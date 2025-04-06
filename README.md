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

