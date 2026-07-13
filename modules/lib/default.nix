{ lib, ... }:
{
  _module.args.utils = import ./utils.nix { inherit lib; };
}
