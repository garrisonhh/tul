# **TUL**. a **t**iny **u**seful **l**anguage.

this is really just a toy project to explore simplicity in embedded, interpreted
language design. the goal here for me is to make something that works and is
hopefully useful for simple scripting tasks.

## how 2 build?

`$ zig build` with zig 0.11.0, which is the current stable zig as of writing
this.

## how 2 embed?

tul exposes `tul` as a module for your `build.zig`.