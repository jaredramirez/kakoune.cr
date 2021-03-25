{ pkgs ? import <nixpkgs> { } }:

# This derivation builds kakoune.cr
#
# The most unusual thing this does is it replaces all run-time dependencies
# such as jq, fzf, etc with the path to the bin in the nix store. This is
# to ensure that nothing else is needed to use kakoune.cr outside this derivation.

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
  buildInputs = with pkgs; [ crystal amber ];
  propagatedBuildInputs = with pkgs; [ jq fzf bat ripgrep git ];
  configurePhase = ''
    ln -s ${crystalLib} lib
  '';
  buildPhase = ''
    ambr "jq" "${pkgs.jq}/bin/jq" --no-interactive src/
    ambr "git describe --tags --always" "echo \"${version}\"" --no-interactive src/
    crystal build src/cli.cr -o kcr --release
  '';
  installPhase = ''
    bin_dir="$out/bin"
    mkdir -p "$bin_dir"

    kcr_bin="$bin_dir/kcr"

    ambr "kcr get" "$kcr_bin get" --no-interactive share/kcr/commands
    ambr "kcr send" "$kcr_bin send" --no-interactive share/kcr/commands
    ambr "kcr edit" "$kcr_bin edit" --no-interactive share/kcr/commands
    ambr "kcr list" "$kcr_bin list" --no-interactive share/kcr/commands
    ambr "kcr shell" "$kcr_bin shell" --no-interactive share/kcr/commands

    ambr "fzf --" "${pkgs.fzf}/bin/fzf --" --no-interactive share/kcr/commands/fzf
    ambr "bat --" "${pkgs.bat}/bin/bat --" --no-interactive share/kcr/commands/fzf
    ambr "rg --" "${pkgs.ripgrep}/bin/rg --" --no-interactive share/kcr/commands/fzf

    cp $(ls share/kcr/commands/*/kcr-*) "$bin_dir"
    cp "kcr" "$kcr_bin"
    cp -r share "$out/share"

  '';
}
