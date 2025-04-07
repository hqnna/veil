{
  inputs = {
    utils.url = "github:numtide/flake-utils/main";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem(system:
      let
        pkgs = import nixpkgs { inherit system; };
        cache = import ./nix/cache.nix { inherit pkgs; };
      in {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [ zig zls ];
        };

        packages.default = self.packages.${system}.release;

        packages.release = pkgs.stdenv.mkDerivation {
          pname = "veil";
          version = "0.1.0";
          doCheck = false;
          src = ./.;

          nativeBuildInputs = with pkgs; [ zig ];

          buildPhase = ''
            export ZIG_GLOBAL_CACHE_DIR=$(mktemp -d)
            ln -sf ${cache} $ZIG_GLOBAL_CACHE_DIR/p
            zig build -Doptimize=ReleaseFast --summary new
          '';

          installPhase = ''
            install -Ds -m755 zig-out/bin/veil $out/bin/veil
          '';

          meta = with pkgs.lib; {
            description = "An encrypted storage utility for the command line";
            homepage = "https://git.sr.ht/~sapphic/veil";
            maintainers = with maintainers; [ sapphic ];
            platforms = platforms.linux;
            license = licenses.bsd3Clear;
          };
        };

        packages.debug = self.packages.${system}.release.overrideAttrs(old: {
          version = "${old.version}-dev";

          buildPhase = ''
            export ZIG_GLOBAL_CACHE_DIR=$(mktemp -d)
            ln -sf ${cache} $ZIG_GLOBAL_CACHE_DIR/p
            zig build -Doptimize=Debug --summary all
          '';

          installPhase = ''
            install -D -m755 zig-out/bin/veil $out/bin/veil
          '';
        });
      });
}
