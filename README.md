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

## Security information

Veil takes advantages of multiple technologies, primarily the following:
1. **Ed25519** for user identities and keypairs, as well as signing encrypted data.
2. **X25519** keys are derived from the user's identity and are used to create keys.
3. **Aegis256x4** is used for actual encryption of file data and directory names.
4. **Blake3** is used to hash file names, with original names being encrypted.
5. **Base64** and **Hex** to encode data that has been encrypted for storage.

### How to report security issues

If you find a security vulnerability in Veil, please [email me](mailto:me@hanna.lol)
directly and I will research a fix. **Do not** report security vulnerabilities
on the public email list where they can be easily exposed and visible. I *might*
offer bounties for people who find vulnerabilities that entirely compromise the
integrity of the software, but for most vulnerabilities there will not be one
due to this being a hobby project.

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
