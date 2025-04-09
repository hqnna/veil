{ pkgs, zig, ... }:

pkgs.stdenv.mkDerivation {
  pname = "veil-cache";
  version = "0.1.0";
  doCheck = false;
  src = ../.;

  nativeBuildInputs = with pkgs; [ zig.master ];

  buildPhase = ''
    export ZIG_GLOBAL_CACHE_DIR=$(mktemp -d)
    zig build --fetch --summary none
  '';

  installPhase = ''
    mv $ZIG_GLOBAL_CACHE_DIR/p $out
  '';

  outputHash = "sha256-+wrqOin+0+RnP1aJe5J4YKF0LjC2SnQQa3gT4JnTeoU=";
  outputHashMode = "recursive";
  outputHashAlgo = "sha256";
}
