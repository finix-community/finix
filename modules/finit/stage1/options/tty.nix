{ lib, program }:
{ name, config, ... }:
{
  options = import ../../lib/options/tty.nix { inherit lib program; };

  config.device = lib.mkIf (config.command == null) (lib.mkDefault name);
}
