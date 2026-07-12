{ lib, program }:
{ name, ... }:
{
  options = import ../../lib/options/exec.nix { inherit lib program; };

  config = {
    name = lib.head (lib.splitString "@" name);
    id = if lib.hasInfix "@" name then lib.elemAt (lib.splitString "@" name) 1 else null;
  };
}