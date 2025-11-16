{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.regreet;
  format = pkgs.formats.toml { };

  configFile = format.generate "regreet.toml" cfg.settings;

  # libudev-zero is a hard requirement when running mdevd
  libinput = pkgs.libinput.override (
    lib.optionalAttrs config.services.mdevd.enable {
      udev = pkgs.libudev-zero;
      wacomSupport = false;
    }
  );

  wlroots_0_19 = pkgs.wlroots_0_19.override {
    inherit libinput;

    # xwayland appears to cause issues with mdevd - and not required in this context, so no harm in removing
    enableXWayland = !config.services.mdevd.enable;
  };
in
{
  options.programs.regreet = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [regreet](${pkgs.regreet.meta.homepage}).

        ::: {.note}
        `regreet` will be run using [cage](${pkgs.cage.meta.homepage}) as a compositor
        and can be configured using the `programs.regreet.compositor.*` options.
        :::
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.regreet;
      defaultText = lib.literalExpression "pkgs.regreet";
      description = ''
        The package to use for `regreet`.
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
        `regreet` configuration. See [upstream documentation](https://github.com/rharish101/ReGreet/blob/main/regreet.sample.toml)
        for additional details.
      '';
    };

    compositor = {
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.cage.override {
          inherit wlroots_0_19;
        };
        defaultText = lib.literalExpression "pkgs.cage";
        description = ''
          The package to use for `cage`.
        '';
      };

      extraArgs = lib.mkOption {
        type = with lib.types; listOf str;
        default = [ "-s" ];
        description = ''
          Additional arguments to pass to `cage`. See [upstream documentation](https://github.com/cage-kiosk/cage/blob/master/cage.1.scd#options)
          for additional details.
        '';
      };

      environment = lib.mkOption {
        type = with lib.types; attrsOf str;
        default = { };
        example = {
          XKB_DEFAULT_LAYOUT = "us";
          XKB_DEFAULT_VARIANT = "dvorak";
        };
        description = ''
          Environment variables to pass to `cage`. See [upstream documentation](https://github.com/cage-kiosk/cage/blob/master/cage.1.scd#environment)
          for additional details.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.greetd.enable = true;
    services.greetd.settings = {
      default_session = {
        command =
          "env ${
            lib.concatMapAttrsStringSep " " (k: v: "${k}=${toString v}") cfg.compositor.environment
          } ${lib.getExe cfg.compositor.package} ${toString cfg.compositor.extraArgs} -- ${lib.getExe cfg.package} --config ${configFile}"
          + lib.optionalString cfg.debug " --log-level debug";
      };
    };

    programs.regreet.settings = {
      GTK = {
        application_prefer_dark_theme = true;
      };

      commands = lib.mkMerge [
        (lib.mkIf config.services.seatd.enable {
          reboot = [
            config.providers.privileges.command
            "/run/current-system/sw/bin/reboot"
          ];
          poweroff = [
            config.providers.privileges.command
            "/run/current-system/sw/bin/poweroff"
          ];
        })

        (lib.mkIf config.services.elogind.enable {
          reboot = [
            "loginctl"
            "reboot"
          ];
          poweroff = [
            "loginctl"
            "poweroff"
          ];
        })
      ];
    };

    providers.privileges.rules = lib.mkIf config.services.seatd.enable [
      {
        command = "/run/current-system/sw/bin/reboot";
        users = [ "greeter" ];
        requirePassword = false;
      }
      {
        command = "/run/current-system/sw/bin/poweroff";
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
