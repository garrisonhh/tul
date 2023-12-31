const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;
const tul = @import("tul");
const bc = tul.bc;
const Function = bc.Function;
const Inst = bc.Inst;
const Object = tul.Object;

/// context for function execution
pub const Frame = struct {
    const Self = @This();
    const Stack = std.ArrayListUnmanaged(Object.Ref);

    func_ref: Object.Ref,
    func: *const Function,
    stack: Stack,
    iter: bc.Iterator,

    pub fn init(ally: Allocator, func_ref: Object.Ref) Allocator.Error!Self {
        tul.acq(func_ref);
        const func = &tul.get(func_ref).@"fn";
        return Self{
            .func_ref = func_ref,
            .func = func,
            .stack = try Stack.initCapacity(ally, func.stack_size),
            .iter = bc.iterator(func.code),
        };
    }

    pub fn deinit(self: *Self, ally: Allocator) void {
        tul.deacq(self.func_ref);
        // params may be left over on the stack when this terminates
        tul.deacqAll(self.stack.items);
        self.stack.deinit(ally);
    }

    /// ensure stack has `num_items` items
    fn assertStack(self: Self, num_items: usize) void {
        std.debug.assert(self.stack.items.len >= num_items);
    }

    /// use code iterator through this
    pub fn nextInst(self: *Self, consumed: *u64) bc.Iterator.Error!?Inst {
        return self.iter.next(consumed);
    }

    pub fn push(self: *Self, ref: Object.Ref) void {
        self.stack.appendAssumeCapacity(ref);
    }

    pub fn pushAll(self: *Self, refs: []const Object.Ref) void {
        for (refs) |ref| self.push(ref);
    }

    pub fn pop(self: *Self) Object.Ref {
        self.assertStack(1);
        return self.stack.pop();
    }

    pub fn popArray(self: *Self, comptime N: comptime_int) [N]Object.Ref {
        const arr = self.peekArray(N);
        self.stack.shrinkRetainingCapacity(self.stack.items.len - N);
        return arr;
    }

    pub fn popSliceAlloc(
        self: *Self,
        ally: Allocator,
        len: usize,
    ) Allocator.Error![]const Object.Ref {
        self.assertStack(len);

        const index = self.stack.items.len - len;
        defer self.stack.shrinkRetainingCapacity(index);

        const slice = self.stack.items[index..];
        return try ally.dupe(Object.Ref, slice);
    }

    pub fn peek(self: Self) Object.Ref {
        self.assertStack(1);
        return self.stack.getLast();
    }

    pub fn peekArray(self: Self, comptime N: comptime_int) [N]Object.Ref {
        self.assertStack(N);
        var arr: [N]Object.Ref = undefined;
        @memcpy(&arr, self.stack.items[self.stack.items.len - N ..]);
        return arr;
    }

    pub fn getAbs(self: Self, index: usize) Object.Ref {
        self.assertStack(index);
        return self.stack.items[index];
    }

    /// jump to an instruction address
    pub fn jump(self: *Self, index: usize) void {
        self.iter.jump(index);
    }
};

/// context for execution
const Process = struct {
    const Self = @This();

    const CallStack = std.SinglyLinkedList(Frame);

    stack: CallStack = .{},

    fn getFrame(self: *Self) ?*Frame {
        return if (self.stack.first) |node| &node.data else null;
    }

    /// adds a frame to the call stack
    fn call(
        self: *Self,
        ally: Allocator,
        func_ref: Object.Ref,
        args: []const Object.Ref,
    ) Allocator.Error!void {
        // make and store frame
        const frame = try Frame.init(ally, func_ref);
        const node = try ally.create(CallStack.Node);
        node.* = .{ .data = frame };

        self.stack.prepend(node);

        // add args
        node.data.pushAll(args);
    }

    /// removes a frame from the call stack
    fn ret(self: *Self, ally: Allocator) Object.Ref {
        const node = self.stack.popFirst().?;
        const value = node.data.pop();

        node.data.deinit(ally);
        ally.destroy(node);

        return value;
    }
};

// =============================================================================

/// needs to exist to prevent dependency loop between vm.Error and EvalError
pub const PipelineError = Allocator.Error || bc.Iterator.Error;
pub const Error = PipelineError || tul.EvalError;

fn execInst(
    proc: *Process,
    frame: *Frame,
    inst: bc.Inst,
    consumed: u64,
) Error!void {
    const func = frame.func;

    // execute
    switch (inst) {
        .nop => {},

        .load_const => {
            const ref = func.consts[consumed];
            tul.acq(ref);
            frame.push(ref);
        },
        .load_abs => {
            const ref = frame.getAbs(consumed);
            tul.acq(ref);
            frame.push(ref);
        },
        .inspect => {
            const obj = tul.get(frame.peek());
            std.debug.print("[inspect] {}\n", .{obj});
        },
        .eval => {
            const code = frame.pop();
            defer tul.deacq(code);
            frame.push(try tul.eval(code));
        },
        .@"fn" => {
            const refs = frame.popArray(2);
            defer tul.deacqAll(&refs);

            const args = refs[0];
            const body = refs[1];

            frame.push(try tul.evalFunction(args, body));
        },

        // control flow
        .call => {
            const refs = try frame.popSliceAlloc(tul.gc.ally, consumed);
            defer tul.gc.ally.free(refs);

            const app = refs[0];
            defer tul.deacq(app);
            // arg ownership is passed over to called function
            const args = refs[1..];

            _ = try proc.call(tul.gc.ally, app, args);
        },
        .jump => {
            frame.jump(consumed);
        },
        .branch => {
            const cond = cond: {
                const ref = frame.pop();
                defer tul.deacq(ref);
                break :cond tul.get(ref).bool;
            };

            if (cond) frame.jump(consumed);
        },

        // stack manipulation
        .swap => {
            var refs = frame.popArray(2);
            std.mem.swap(Object.Ref, &refs[0], &refs[1]);
            frame.pushAll(&refs);
        },
        .dup => {
            const top = frame.peek();
            tul.acq(top);
            frame.push(top);
        },
        .over => {
            const under = frame.peekArray(2)[0];
            tul.acq(under);
            frame.push(under);
        },
        .rot => {
            var refs = frame.popArray(3);
            const tmp = refs[0];
            refs[0] = refs[1];
            refs[1] = refs[2];
            refs[2] = tmp;
            frame.pushAll(&refs);
        },
        .drop => {
            tul.deacq(frame.pop());
        },

        // math
        inline .add, .sub, .mul, .div, .mod => |tag| {
            const refs = frame.popArray(2);
            defer tul.deacqAll(&refs);

            const lhs = tul.get(refs[0]).int;
            const rhs = tul.get(refs[1]).int;

            const val = switch (tag) {
                .add => lhs + rhs,
                .sub => lhs - rhs,
                .mul => lhs * rhs,
                .div => @divTrunc(lhs, rhs),
                .mod => @mod(lhs, rhs),
                else => unreachable,
            };

            frame.push(try tul.new(.{ .int = val }));
        },

        // logic
        inline .land, .lor => |tag| {
            const refs = frame.popArray(2);
            defer tul.deacqAll(&refs);

            const lhs = tul.get(refs[0]).bool;
            const rhs = tul.get(refs[1]).bool;

            const val = switch (tag) {
                .land => lhs and rhs,
                .lor => lhs or rhs,
                else => unreachable,
            };

            frame.push(try tul.new(.{ .bool = val }));
        },
        .lnot => {
            const ref = frame.pop();
            defer tul.deacq(ref);

            const val = !tul.get(ref).bool;
            frame.push(try tul.new(.{ .bool = val }));
        },

        // comparison
        .eq => {
            const refs = frame.popArray(2);
            defer tul.deacqAll(&refs);

            const res = Object.eql(refs[0], refs[1]);

            frame.push(try tul.new(.{ .bool = res }));
        },

        // strings/lists
        .concat => {
            const refs = frame.popArray(2);
            defer tul.deacqAll(&refs);

            const lhs_ref = tul.get(refs[0]);
            const rhs_ref = tul.get(refs[1]);

            if (lhs_ref.* == .string) {
                const lhs = lhs_ref.string;
                const rhs = rhs_ref.string;

                const str = try std.mem.concat(tul.gc.ally, u8, &.{ lhs, rhs });

                frame.push(try tul.put(.{ .string = str }));
            } else if (lhs_ref.* == .list) {
                const lhs = lhs_ref.list;
                const rhs = rhs_ref.list;

                const list = try std.mem.concat(
                    tul.gc.ally,
                    Object.Ref,
                    &.{ lhs, rhs },
                );
                tul.acqAll(list);

                frame.push(try tul.put(.{ .list = list }));
            } else {
                @panic("TODO runtime error; mismatched concat");
            }
        },
        .list => {
            // technically, this should deacq all refs when popping and then
            // reacq when placing on the list, but I think that is
            // unnecessary work
            const list = try frame.popSliceAlloc(tul.gc.ally, consumed);
            frame.push(try tul.put(.{ .list = list }));
        },
        .put => {
            const refs = frame.popArray(3);
            const map_in = refs[0];
            const key = refs[1];
            const value = refs[2];

            // if there is one ref, the map can be safely mutated. otherwise,
            // a clone must be made
            const map_out = if (tul.gc.refCount(map_in) == 1) mut: {
                break :mut map_in;
            } else clone: {
                const cloned = try tul.get(map_in).clone(tul.gc.ally);
                tul.deacq(map_in);
                break :clone try tul.put(cloned);
            };

            // add to this map, respecting ownership rules
            const map = &tul.gc.getMut(map_out).map;
            const res = try map.getOrPut(tul.gc.ally, key);
            if (res.found_existing) {
                tul.deacq(key);
                tul.deacq(res.value_ptr.*);
            }

            res.value_ptr.* = value;

            // push map
            frame.push(map_out);
        },
        .get => {
            const refs = frame.popArray(2);
            defer tul.deacqAll(&refs);

            const map_ref = refs[0];
            const key = refs[1];

            const map = &tul.get(map_ref).map;
            if (map.get(key)) |value| {
                // value exists
                tul.acq(value);
                frame.push(value);
            } else {
                // value does not exist, return a unit
                frame.push(try tul.put(.{ .list = &.{} }));
            }
        },
    }
}

/// run a program on the vm (in the form of a function that takes 0 parameters)
pub fn run(main: Object.Ref) Error!Object.Ref {
    const func = &tul.get(main).@"fn";
    std.debug.assert(func.param_count == 0);

    // start process
    var proc = Process{};
    try proc.call(tul.gc.ally, main, &.{});

    // main vm loop
    while (true) {
        var consumed: u64 = undefined;

        // get next instruction and frame, if program continues
        var frame = proc.getFrame().?;
        const inst = inst: while (true) {
            if (try frame.iter.next(&consumed)) |inst| {
                break :inst inst;
            }

            const returned = proc.ret(tul.gc.ally);
            if (proc.getFrame()) |next_frame| {
                // return value to previous function
                frame = next_frame;
                frame.push(returned);
            } else {
                // return value to main
                return returned;
            }
        };

        try execInst(&proc, frame, inst, consumed);
    }
}
