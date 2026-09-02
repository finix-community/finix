{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.sysklogd;
in
{
  options.services.sysklogd = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [sysklogd](${pkgs.sysklogd.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.sysklogd;
      defaultText = lib.literalExpression "pkgs.sysklogd";
      description = ''
        The package to use for `sysklogd`.
      '';
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Additional `sysklogd` configuration. See {manpage}`syslog.conf(5)`
        for additional details.
      '';
    };
  };

  # finit has explicit sysklogd support, requires `logger` to be available in `PATH`
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
    finit.path = [
      cfg.package
    ];

    finit.services.syslogd = {
      description = "system logging daemon";
      runlevels = "S0123456789";
      # Daemon up, not full settle: coldplug/settle may be non-blocking or killed at the runlevel change
      # syslogd must not wait on their success
      conditions =
        lib.optionals config.services.gardendevd.enable [ "service/gardendevd/ready" ]
        ++ lib.optionals config.services.keventd.enable [ "service/keventd/ready" ]
        ++ lib.optionals config.services.udev.enable [ "service/udevd/ready" ]
        ++ lib.optionals config.services.mdevd.enable [ "service/mdevd/ready" ];
      command = "${cfg.package}/bin/syslogd -F";
      notify = "pid";
    };

    environment.etc."syslog.d/nixos.conf".text = cfg.extraConfig;
    environment.etc."syslog.conf".source =
      lib.mkDefault "${cfg.package}/share/doc/sysklogd/syslog.conf";

    # TODO: add finit.services.reloadTriggers option
    environment.etc."finit.d/syslogd.conf".text = lib.mkAfter ''

      # reload trigger
      # ${config.environment.etc."syslog.d/nixos.conf".source}
      # ${config.environment.etc."syslog.conf".source}
    '';

    system.switch.inhibitors.syslogd = config.finit.services.syslogd.command;
  };
}
