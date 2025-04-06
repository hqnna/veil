Veil
![license](https://badge.hanna.lol/license/BSD-3-Clause-Clear)
![status](https://badge.hanna.lol/status/veil)
================================================================================

An encrypted file storage utility and personal vault for the command line.

## Building from source

The recommended way to build from source is to use the [flake](flake.nix) and
run the following:

```console
$ nix build $PWD#debug
```

This will build a **debug** binary. If you want to actually use veil, you can do
the following instead:

```console
$ nix build $PWD#release
```

Which will build a **release** binary which is optimized for performance and is
also stripped.

---

If you do not want to use Nix, you will need the latest tagged version of the 
[Zig](https://ziglang.org) compiler, then run:

```console
$ zig build -Doptimize=Debug --summary all
```

This will build a **debug** binary without the use of Nix. To instead build a
**release** binary, run the following:

```console
$ zig build -Doptimize=ReleaseFast --summary all
$ strip -s zig-out/bin/veil
```

These two commands will build a performance optimized binary then strip it, like
the nix package.
