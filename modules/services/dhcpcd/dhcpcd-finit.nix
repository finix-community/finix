{
  config,
  lib,
  ...
}:
let
  cfg = config.services.dhcpcd;
in
{
  config = lib.mkIf cfg.enable {
    finit.services.dhcpcd = {
      description = "dhcp client";
      command =
        "${lib.getExe cfg.package} "
        + lib.escapeShellArgs (
          [
            "-B"
            "-f"
            (toString cfg.configFile)
          ]
          ++ cfg.extraArgs
        );
      conditions = "service/syslogd/ready";

      path = lib.optionals config.programs.resolvconf.enable [
        config.programs.resolvconf.package
      ];
    };
  };
}
