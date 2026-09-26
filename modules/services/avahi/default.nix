{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.avahi;

  mkValueString =
    v:
    if v == true then
      "yes"
    else if v == false then
      "no"
    else
      lib.generators.mkValueStringDefault { } v;

  format = pkgs.formats.ini {
    mkKeyValue = lib.generators.mkKeyValueDefault { inherit mkValueString; } "=";
    listToValue = lib.concatMapStringsSep ", " mkValueString;
  };

  enableDbus = cfg.settings.server.enable-dbus or true;
in
{
  options.services.avahi = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [avahi](${pkgs.avahi.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.avahi;
      defaultText = lib.literalExpression "pkgs.avahi";
      description = ''
        The package to use for `avahi`.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.
      '';
    };

    extraArgs = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = ''
        Additional arguments to pass to `avahi`. See {manpage}`avahi-daemon(8)`
        for additional details.
      '';
    };

    settings = lib.mkOption {
      type = format.type;
      default = { };
      description = ''
        `avahi` configuration. See {manpage}`avahi-daemon.conf(5)`
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.avahi.extraArgs = [ "--syslog" ] ++ lib.optionals cfg.debug [ "--debug" ];
    services.avahi.settings = {
      server = { };
    };

    environment.systemPackages = [ cfg.package ];

    environment.etc."avahi/avahi-daemon.conf".source = format.generate "avahi-daemon.conf" cfg.settings;

    # TODO: add finit.services.reloadTriggers option
    environment.etc."finit.d/avahi-daemon.conf".text = lib.mkAfter ''

      # reload trigger
      # ${config.environment.etc."avahi/avahi-daemon.conf".source}
    '';

    finit.services.avahi-daemon = {
      description = "avahi daemon service";
      conditions = [
        "service/syslogd/ready"
      ]
      ++ lib.optionals enableDbus [ "service/dbus/ready" ];
      command = lib.escapeShellArgs (
        [
          (lib.getExe' cfg.package "avahi-daemon")
        ]
        ++ cfg.extraArgs
      );
    };

    services.dbus = lib.optionalAttrs enableDbus {
      enable = true;
      packages = [ cfg.package ];
    };

    users.users.avahi = {
      description = "avahi-daemon privilege separation user";
      home = "/var/empty";
      group = "avahi";
      isSystemUser = true;
    };

    users.groups.avahi = { };
  };
}
