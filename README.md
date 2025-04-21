Veil
![license](https://badge.hanna.lol/license/BSD-3-Clause-Clear)
![status](https://badge.hanna.lol/status/veil)
================================================================================

An encrypted file storage utility and personal vault for the command line.

## Usage

To get started you will want to first initialize a keypair to encrypt with:

```console
$ veil init
public key: 9b6lJZjWzIMafx+D2gsTRO/iCQtRwM9DCykyFzkIX8M=
```

This will create and store a keypair in `$HOME/.local/share/veil` for later use,
then do something like:

```console
$ veil lock README.md
successfully encrypted README.md as d22c79d53c55d9c11c46b8cb956e40faef538ae4b7df355c0d5ad1e6e5ce7963
```

This gives you the hashed file name (or encrypted folder name) of the thing you
just encrypted, to decrypt:

```console
$ veil unlock d22c79d53c55d9c11c46b8cb956e40faef538ae4b7df355c0d5ad1e6e5ce7963
successfully decrypted d22c79d53c55d9c11c46b8cb956e40faef538ae4b7df355c0d5ad1e6e5ce7963 as README.md
```

This will decrypt the file and restore the original file name, it verifies the
decrypted contents before saving.

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

If you do not want to use Nix, you will need the latest master version of the 
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
