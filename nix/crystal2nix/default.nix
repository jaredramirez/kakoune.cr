{ pkgs ? import <nixpkgs> { } }:

pkgs.stdenv.mkDerivation rec {
  pname = "crystal2nix";
  version = "unstable-2021-03-17";
  src = ./.;
  buildInputs = with pkgs; [
    crystal
  ];
  buildPhase = ''
    crystal build -o "${pname}" ./main.cr
  '';
  installPhase = ''
    mkdir -p "$out/bin"
    cp "${pname}" "$out/bin/${pname}"
  '';
}
