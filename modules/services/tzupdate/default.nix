{ config, pkgs, lib, ... }:
let
  cfg = config.services.tzupdate;
in
{
  options.services.tzupdate = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.tzupdate;
    };
  };

  config = lib.mkIf cfg.enable {
    time.timeZone = null;

    finit.tasks.tzupdate = {
      description = "timezone update service";
      command = "${cfg.package}/bin/tzupdate -z ${pkgs.tzdata}/share/zoneinfo -d /dev/null";
      conditions = [ "service/syslogd/ready" "net/route/default" ];
    };
  };
}
