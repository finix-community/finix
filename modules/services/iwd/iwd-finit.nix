{
  config,
  lib,
  ...
}:
let
  cfg = config.services.iwd;
in
{
  config = lib.mkIf (config.system.init == "finit" && cfg.enable) {
    finit.services.iwd = {
      description = "wireless service";
      conditions = "service/syslogd/ready";
      command = "${cfg.package}/libexec/iwd" + lib.optionalString cfg.debug " -d";
      nohup = true;
      log = true;

      path = lib.optionals config.programs.resolvconf.enable [
        config.programs.resolvconf.package
      ];
    };

    # TODO: add finit.services.restartTriggers option
    environment.etc."finit.d/iwd.conf" = lib.mkIf config.finit.services.iwd.enable {
      text = lib.mkAfter ''

        # standard nixos trick to force a restart when something has changed
        # ${config.environment.etc."iwd/main.conf".source}
      '';
    };
  };
}
