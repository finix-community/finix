{ config, pkgs, lib, ... }:
let
  cfg = config.programs.regreet;
  format = pkgs.formats.toml { };

  configFile = format.generate "regreet.toml" cfg.settings;
in
{
  options.programs.regreet = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.regreet;
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
    services.greetd.enable = true;
    services.greetd.settings = {
      default_session = {
        command = "${lib.getExe pkgs.cage} -s -m last -- ${lib.getExe cfg.package} --config ${configFile}" + lib.optionalString cfg.debug " --log-level debug";
      };
    };

    programs.regreet.settings = {
      GTK = {
        application_prefer_dark_theme = true;
      };

      commands = lib.mkMerge [
        (lib.mkIf config.services.seatd.enable {
          reboot = [ "sudo" "reboot" ];
          poweroff = [ "sudo" "poweroff" ];
        })

        (lib.mkIf config.services.elogind.enable {
          reboot = [ "loginctl" "reboot" ];
          poweroff = [ "loginctl" "poweroff" ];
        })
      ];
    };

    providers.privileges.rules = lib.mkIf config.services.seatd.enable [
      { command = "/run/current-system/sw/bin/poweroff";
        users = [ "greeter" ];
        requirePassword = false;
      }
      { command = "/run/current-system/sw/bin/reboot";
        users = [ "greeter" ];
        requirePassword = false;
      }
    ];

    services.tmpfiles.regreet.rules = [
      "d /var/log/regreet 0755 greeter greeter - -"
      "d /var/lib/regreet 0755 greeter greeter - -"
    ];
  };
}
