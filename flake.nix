{
  inputs = {
    zlspkgs.url = "github:zigtools/zls/master";
    utils.url = "github:numtide/flake-utils/main";
    zigpkgs.url = "github:mitchellh/zig-overlay/main";
    zlspkgs.inputs.zig-overlay.follows = "zigpkgs";
    zigpkgs.inputs.flake-utils.follows = "utils";
    zigpkgs.inputs.nixpkgs.follows = "nixpkgs";
    zlspkgs.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, zigpkgs, zlspkgs, utils }:
    utils.lib.eachDefaultSystem(system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        zig = zigpkgs.packages.${system};
        zls = zlspkgs.packages.${system};
        cache = import ./nix/cache.nix {
          inherit pkgs;
          inherit zig;
        };
      in {
        devShells.default = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            zls.default
            zig.master
          ];
        };

        packages.default = self.packages.${system}.release;

        packages.release = pkgs.stdenv.mkDerivation {
          pname = "veil";
          version = "0.1.0";
          doCheck = false;
          src = ./.;

          nativeBuildInputs = with pkgs; [ zig.master ];

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
          version = "${old.version}-debug";

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
