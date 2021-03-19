{ pkgs ? import <nixpkgs> { } }:

let
    crystalLib = pkgs.linkFarm "crystal-lib" (pkgs.lib.mapAttrsToList (name: value: {
      inherit name;
      path = builtins.fetchGit value;
    }) (import ./nix/shard.nix));
in
pkgs.stdenv.mkDerivation rec {
  pname = "kakoune.cr";
  version = "nightly-2021-03-17";
  src = ./.;
  buildInputs = with pkgs; [ crystal jq git ];
  configurePhase = ''
    ln -s ${crystalLib} lib
  '';
  buildPhase = ''
    ls -a
    crystal build src/cli.cr -o kcr --release
  '';
  installPhase = ''
    mkdir -p "$out/bin"
    cp "kcr" "$out/bin/kcr"
    cp -r share "$out/share"
  '';
}
