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

  outputHash = "sha256-3ASEmARI1CVBAP1R1YvnSc+xexBeivy2ga6EPrOB8w0=";
  outputHashMode = "recursive";
  outputHashAlgo = "sha256";
}
