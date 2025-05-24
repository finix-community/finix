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
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.iwd;
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    settings = lib.mkOption {
      type = format.type;
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    services.iwd.settings = {
      General = {
        EnableNetworkConfiguration = true;
      };

      Network = {
        NameResolvingService = "resolvconf";
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
      env = pkgs.writeText "iwd.env" ''
        PATH="${lib.makeBinPath [ pkgs.openresolv ]}:$PATH"
      '';
    };

    # TODO: add finit.services.restartTriggers option
    environment.etc."finit.d/iwd.conf".text = lib.mkAfter ''

      # standard nixos trick to force a restart when something has changed
      # ${config.environment.etc."iwd/main.conf".source}
    '';
  };
}
