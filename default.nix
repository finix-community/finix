let
  flake = import ./flake.nix;

  self = flake.outputs { inherit self; };
in
self
