{
  config,
  lib,
  ...
}:
let
  cfg = config.services.sysklogd;
in
{
  # Finit has explicit sysklogd support, requiring `logger` in its PATH.
  options.finit = lib.optionalAttrs cfg.enable {
    services = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { config, ... }:
          {
            config.path = lib.optionals (config.log != false) [ cfg.package ];
          }
        )
      );
    };

    tasks = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { config, ... }:
          {
            config.path = lib.optionals (config.log != false) [ cfg.package ];
          }
        )
      );
    };
  };

  config = lib.mkIf cfg.enable {
    # finit has explicit sysklogd support, requires `logger` to be available in `PATH`
    finit.path = [ cfg.package ];

    finit.services.syslogd = {
      description = "system logging daemon";
      runlevels = "S0123456789";
      conditions =
        lib.optionals config.services.gardendevd.enable [ "run/gardendevctl:2/success" ]
        ++ lib.optionals config.services.keventd.enable [ "pid/keventd" ]
        ++ lib.optionals config.services.udev.enable [ "run/udevadm:5/success" ]
        ++ lib.optionals config.services.mdevd.enable [ "run/coldplug/success" ];
      command = "${cfg.package}/bin/syslogd -F";
      notify = "pid";
    };

    system.switch.inhibitors.syslogd = lib.mkIf (
      config.system.init == "finit"
    ) config.finit.services.syslogd.command;

    # TODO: add finit.services.reloadTriggers option
    environment.etc."finit.d/syslogd.conf" =
      lib.mkIf (config.system.init == "finit" && config.finit.services.syslogd.enable)
        {
          text = lib.mkAfter ''

            # reload trigger
            # ${config.environment.etc."syslog.d/nixos.conf".source}
            # ${config.environment.etc."syslog.conf".source}
          '';
        };
  };
}
