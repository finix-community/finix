{ config, pkgs, lib, ... }:
let
  cfg = config.services.earlyoom;
in
{
  options.services.earlyoom = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.earlyoom;
    };
  };

  config = lib.mkIf cfg.enable {
    finit.services.earlyoom = {
      description = "early oom daemon";
      command = "${cfg.package}/bin/earlyoom --syslog -r 3600";
    };
  };
}
