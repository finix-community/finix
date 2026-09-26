{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.elogind;

  format = pkgs.formats.systemd { };
in
{
  options.services.elogind = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [elogind](${pkgs.elogind.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.elogind;
      defaultText = lib.literalExpression "pkgs.elogind";
      description = ''
        The package to use for `elogind`.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.
      '';
    };

    settings.Login = lib.mkOption {
      type = (pkgs.formats.keyValue { }).type;
      default = { };
      description = ''
        `elogind` login manager configuration. See {manpage}`logind.conf(5)`
        for additional details.
      '';
    };

    settings.Sleep = lib.mkOption {
      type = (pkgs.formats.keyValue { }).type;
      default = { };
      description = ''
        `elogind` suspend and hibernation configuration. See {manpage}`sleep.conf(5)`
        for additional details.
      '';
    };
  };

  # extend finit.ttys to add elogind readiness conditions
  options.finit.ttys = lib.mkOption {
    type =
      with lib.types;
      attrsOf (submodule {
        config = lib.mkIf cfg.enable {
          conditions = "service/elogind/ready";
        };
      });
  };

  config = lib.mkIf cfg.enable {
    finit.services.elogind = {
      description = "login manager";
      conditions = "service/dbus/ready";
      command = "${cfg.package}/libexec/elogind";
      notify = "systemd";
      environment = {
        SYSTEMD_LOG_TARGET = "syslog";
      }
      // lib.optionalAttrs cfg.debug {
        SYSTEMD_LOG_LEVEL = "debug";
      };
    };

    services.dbus.enable = true;
    services.dbus.packages = [ cfg.package ];
    services.udev.packages = [ cfg.package ];

    environment.systemPackages = [ cfg.package ];

    environment.etc."elogind/logind.conf.d/00-nixos.conf".source = format.generate "logind.conf" {
      inherit (cfg.settings) Login;
    };
    environment.etc."elogind/sleep.conf.d/00-nixos.conf".source = format.generate "sleep.conf" {
      inherit (cfg.settings) Sleep;
    };

    # TODO: add finit.services.reloadTriggers option
    environment.etc."finit.d/elogind.conf".text = lib.mkAfter ''

      # reload trigger
      # ${config.environment.etc."elogind/logind.conf.d/00-nixos.conf".source}
      # ${config.environment.etc."elogind/sleep.conf.d/00-nixos.conf".source}
    '';
  };
}
