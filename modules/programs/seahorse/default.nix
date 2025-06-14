{ config, pkgs, lib, ... }:
let
  cfg = config.programs.seahorse;
in
{
  options.programs.seahorse.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.seahorse ];
    services.dbus.packages = [ pkgs.seahorse ];
  };
}
