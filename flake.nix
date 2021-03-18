{
  description = "A flake for building kakoune-cr";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }: {

    defaultPackage.x86_64-darwin =
     with import nixpkgs { system = "x86_64-darwin"; };
       stdenv.mkDerivation {
         name = "kakoune-cr";
         src = self;
         buildInputs = with nixpkgs; [ llvm git crystal shards jq ];
         buildPhase = ''
           make build
         '';
         installPhase = ''
           mkdir -p $out/bin;
           cp bin/kcr $out/bin
           cp -r share $out/share
           chmod +x $out/bin/kcr
         '';
     };

    defaultPackage.x86_64-linux =
     with import nixpkgs { system = "x86_64-linux"; };
       stdenv.mkDerivation {
         name = "kakoune-cr";
         src = self;
         buildInputs = with nixpkgs; [ llvm git crystal shards crystal2nix jq ];
         buildPhase = ''
           make static=yes
         '';
         installPhase = ''
           mkdir -p $out/bin;
           cp bin/kcr $out/bin
           cp -r share $out/share
           chmod +x $out/bin/kcr
         '';
     };

  };
}
