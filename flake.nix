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
          kakoune-cr = import ./default.nix { inherit pkgs; };
          crystal2nix = import ./nix/crystal2nix/default.nix { inherit pkgs; };
        in
          {
            packages =
              flake-utils.lib.flattenTree {
                crystal2nix = crystal2nix;
                kakoune-cr = kakoune-cr;
              };
            defaultPackage = kakoune-cr;
          }
    );
}
