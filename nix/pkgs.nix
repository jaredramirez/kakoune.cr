{ }:

let
  lock = builtins.fromJSON (builtins.readFile ./../flake.lock);
in
import (fetchTarball {
  url = "https://github.com/nixos/nixpkgs/archive/${lock.nodes.nixpkgs.locked.rev}.tar.gz";
  sha256 = lock.nodes.nixpkgs.locked.narHash;
}) { }
