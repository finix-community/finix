{
  config,
  lib,
  ...
}:
let
  cfg = config.services.dhcpcd;
in
{
  config = lib.mkIf (config.system.init == "dinit" && cfg.enable) {
    services.dhcpcd.extraArgs = [
      "-f"
      (toString cfg.configFile)
    ];

    services.dhcpcd.settings.waitip = true;

    dinit.services.dhcpcd = {
      type = "bgprocess";
      command = "${lib.getExe cfg.package} " + lib.escapeShellArgs cfg.extraArgs;
      pid-file = "/run/dhcpcd/pid";
      waits-for =
        lib.optional (config.services ? sysklogd && config.services.sysklogd.enable) "syslogd"
        ++ [ "tmpfiles-setup" ];
      restart = true;
      smooth-recovery = true;
      targets = [ "network" ];

      path = lib.optionals config.programs.resolvconf.enable [
        config.programs.resolvconf.package
      ];
    };

  };
}
