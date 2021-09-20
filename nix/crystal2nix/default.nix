{ pkgs ? import ./nix/pkgs.nix {} }:

pkgs.stdenv.mkDerivation rec {
  pname = "crystal2nix";
  version = "unstable-2021-03-17";
  src = ./.;
  buildInputs = with pkgs; [
    crystal_1_0
  ];
  buildPhase = ''
    ${pkgs.crystal_1_0}/bin/crystal build -o "${pname}" ./main.cr
  '';
  installPhase = ''
    mkdir -p "$out/bin"
    cp "${pname}" "$out/bin/${pname}"
  '';
}
