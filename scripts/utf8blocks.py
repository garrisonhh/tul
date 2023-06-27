#!/usr/bin/env python
"""
processing utf8 block table from wikipedia into a zig enum
"""

import csv
import re
from dataclasses import dataclass
from pprint import pprint

PATH = 'Unicode_block_1.csv'

IDENTIFIER_RE = re.compile(r"[a-zA-Z\d]+")
RANGE_RE = re.compile(r"U\+([\dA-F]+)\.\.U\+([\dA-F]+)")

@dataclass(frozen=True)
class Entry:
    start: int
    stop: int
    name: str

def sentence_to_camelcase(s):
    return "".join([
        match.group().title()
        for match in IDENTIFIER_RE.finditer(s)
    ])

def main():
    # retrieve raw data
    with open(PATH, 'r') as f:
        rows = []
        for row in csv.reader(f):
            rows.append(row)

        rows = rows[2:-1]
    
    # get useful stuff
    entries = []
    for row in rows:
        matched = RANGE_RE.match(row[1])

        start = int(matched.group(1), 16)
        stop = int(matched.group(2), 16)
        name = sentence_to_camelcase(row[2])

        entries.append(Entry(
            start=start,
            stop=stop,
            name=name,
        ))

    # manipulate output
    indent = " " * 4
    enum_members = "\n".join([f"{indent}{entry.name}," for entry in entries])

    block_cases = "\n".join([
        f"{indent * 3}{hex(entry.start)}...{hex(entry.stop)} => .{entry.name},"
        for entry in entries
    ])

    decl = f"""
const utf8 = @import("utf8.zig");
const Codepoint = utf8.Codepoint;

pub const Utf8Block = enum {{
    const Self = @This();

    const Error = error{{ InvalidUtf8 }};

{enum_members}

    pub fn categorize(c: Codepoint) Error!Self {{
        return switch (c.c) {{
{block_cases}
            else => Error.InvalidUtf8,
        }};
    }}
}};
"""

    with open('out.zig', 'w') as f:
        f.write(decl)

if __name__ == '__main__':
    main()