{ pkgs, ... }:

pkgs.stdenv.mkDerivation {
  pname = "veil-cache";
  version = "0.1.0";
  doCheck = false;
  src = ../.;

  nativeBuildInputs = with pkgs; [ zig ];

  buildPhase = ''
    export ZIG_GLOBAL_CACHE_DIR=$(mktemp -d)
    zig build --fetch --summary none
  '';

  installPhase = ''
    mv $ZIG_GLOBAL_CACHE_DIR/p $out
  '';

  outputHash = "sha256-RF2W6/eoR27guLsTO+h8G4r3H3Em34PRs706tlXl0mM=";
  outputHashMode = "recursive";
  outputHashAlgo = "sha256";
}
