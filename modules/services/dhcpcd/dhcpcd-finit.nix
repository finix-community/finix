{
  config,
  lib,
  ...
}:
let
  cfg = config.services.dhcpcd;
in
{
  config = lib.mkIf (config.system.init == "finit" && cfg.enable) {
    services.dhcpcd.extraArgs = [
      "-B"
      "-f"
      (toString cfg.configFile)
    ];

    finit.services.dhcpcd = {
      description = "dhcp client";
      command = "${lib.getExe cfg.package} " + lib.escapeShellArgs cfg.extraArgs;
      conditions = "service/syslogd/ready";

      path = lib.optionals config.programs.resolvconf.enable [
        config.programs.resolvconf.package
      ];
    };
  };
}
