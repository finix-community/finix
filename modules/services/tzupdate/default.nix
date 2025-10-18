{ config, pkgs, lib, ... }:
let
  cfg = config.services.tzupdate;
in
{
  options.services.tzupdate = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [tzupdate](${pkgs.tzupdate.meta.homepage}) as a system startup task.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.tzupdate;
      defaultText = lib.literalExpression "pkgs.tzupdate";
      description = ''
        The package to use for `tzupdate`.
      '';
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
