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

    compositor = {
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.cage;
      };

      args = lib.mkOption {
        type = with lib.types; listOf str;
        default = [ "-s" ];

        # https://github.com/cage-kiosk/cage/blob/master/cage.1.scd#options
      };

      environment = lib.mkOption {
        type = with lib.types; attrsOf str;
        default = { };
        example = {
          XKB_DEFAULT_LAYOUT = "us";
          XKB_DEFAULT_VARIANT = "dvorak";
        };

        # https://github.com/cage-kiosk/cage/blob/master/cage.1.scd#environment
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.greetd.enable = true;
    services.greetd.settings = {
      default_session = {
        command = "env ${lib.concatMapAttrsStringSep " " (k: v: "${k}=${toString v}") cfg.compositor.environment} ${lib.getExe cfg.compositor.package} ${toString cfg.compositor.args} -- ${lib.getExe cfg.package} --config ${configFile}" + lib.optionalString cfg.debug " --log-level debug";
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
