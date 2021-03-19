{
  description = "A flake for building kakoune-cr";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (
      system:
        let
            pkgs = import nixpkgs { inherit system; };
            crystal2nix = import ./nix/crystal2nix/default.nix { inherit pkgs; };
            kakoune-cr = import ./default.nix { inherit pkgs; };
        in
        { packages =
            flake-utils.lib.flattenTree {
              inherit crystal2nix kakoune-cr;
            };
          defaultPackage = kakoune-cr;
        }
    );
}
