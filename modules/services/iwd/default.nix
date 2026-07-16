{
  config,
  pkgs,
  lib,
  ...
}:
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
        # upstream defaults this to false, expecting another service to own IP.
        # default it on so iwd works standalone, but let users hand IP
        # configuration to a dhcp client instead.
        EnableNetworkConfiguration = lib.mkDefault true;
      };

      Network = {
        NameResolvingService = if config.programs.resolvconf.enable then "resolvconf" else "none";
      };
    };

    environment.systemPackages = [ cfg.package ];
    environment.etc."iwd/main.conf".source = format.generate "main.conf" cfg.settings;

    services.dbus.packages = [ cfg.package ];

    finit.tmpfiles.rules = [
      "d /var/lib/iwd 0700"
    ];

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
    environment.etc."finit.d/iwd.conf".text = lib.mkIf config.finit.enable (lib.mkAfter ''

      # standard nixos trick to force a restart when something has changed
      # ${config.environment.etc."iwd/main.conf".source}
    '');
  };
}
