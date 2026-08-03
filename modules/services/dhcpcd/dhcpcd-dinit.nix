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
    services.dhcpcd.settings.waitip = lib.mkIf (config.system.init == "dinit") true;

    dinit.services.dhcpcd = {
      type = "bgprocess";
      command =
        "${lib.getExe cfg.package} "
        + lib.escapeShellArgs (
          [
            "-f"
            (toString cfg.configFile)
          ]
          ++ cfg.extraArgs
        );
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
