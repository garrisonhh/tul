# **TUL**. a **t**iny **u**seful **l**anguage.

this is really just a toy project to explore simplicity in embedded, interpreted
language design. the goal here for me is to make something that works and is
hopefully useful for simple scripting tasks.

## how 2 build?

you have two options:

1. `$ nix build` is consistently tested on my end..
2. you can also just `$ zig build` with zig master. it is quite possible for
   this to break due to zig development, but I am not using any wacky dependency
   management stuff that would otherwise make this hard.

## how 2 embed?

tul exposes `tul` as a module for your `build.zig`.