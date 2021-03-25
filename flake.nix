{
  description = "A flake for building kakoune-cr";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    { overlay = final: prev:
        let pkgs = nixpkgs.legacyPackages.${prev.system};
        in
        { kakoune-cr = import ./default.nix { inherit pkgs; };
          crystal2nix = import ./nix/crystal2nix/default.nix { inherit pkgs; };
        };
    }
    //
    flake-utils.lib.eachDefaultSystem (
      system:
        let
            pkgs = import nixpkgs { inherit system; overlays = [ self.overlay ]; };
        in
        { packages =
            flake-utils.lib.flattenTree {
              crystal2nix = pkgs.crystal2nix;
              kakoune-cr = pkgs.kakoune-cr;
            };
          defaultPackage = pkgs.kakoune-cr;
        }
    );
}
