{ config, pkgs, lib, ... }:
let
  cfg = config.services.iwd;
  format = pkgs.formats.ini { };
in
{
  options.services.iwd = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [iwd](${pkgs.iwd.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.iwd;
      defaultText = lib.literalExpression "pkgs.iwd";
      description = ''
        The package to use for `iwd`.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.
      '';
    };

    settings = lib.mkOption {
      type = format.type;
      default = { };
      description = ''
        `iwd` configuration. See {manpage}`iwd.config(5)`
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.iwd.settings = {
      General = {
        EnableNetworkConfiguration = true;
      };

      Network = {
        NameResolvingService = if config.programs.openresolv.enable or false then "resolvconf" else "none";
      };
    };

    environment.systemPackages = [ cfg.package ];
    environment.etc."iwd/main.conf".source = format.generate "main.conf" cfg.settings;

    services.dbus.packages = [ cfg.package ];

    services.tmpfiles.iwd.rules = [
      "d /var/lib/iwd 0700"
    ];

    finit.services.iwd = {
      description = "wireless service";
      conditions = "service/syslogd/ready";
      command = "${cfg.package}/libexec/iwd" + lib.optionalString cfg.debug " -d";
      nohup = true;
      log = true;

      # TODO: now we're hijacking `env` and no one else can use it...
      env = lib.mkIf (config.programs.openresolv.enable or false) (pkgs.writeText "iwd.env" ''
        PATH="${lib.makeBinPath [ config.programs.openresolv.package ]}:$PATH"
      '');
    };

    # TODO: add finit.services.restartTriggers option
    environment.etc."finit.d/iwd.conf".text = lib.mkAfter ''

      # standard nixos trick to force a restart when something has changed
      # ${config.environment.etc."iwd/main.conf".source}
    '';
  };
}
