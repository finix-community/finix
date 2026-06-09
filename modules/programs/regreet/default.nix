{
  modules,
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.regreet;
  format = pkgs.formats.toml { };

  configFile = format.generate "regreet.toml" cfg.settings;

  # libudev-zero is a hard requirement when running mdevd or keventd
  libinput = pkgs.libinput.override (
    lib.optionalAttrs (config.services.mdevd.enable || config.services.keventd.enable) {
      udev = pkgs.libudev-zero;
      wacomSupport = false;
    }
  );

  wlroots_0_20 = pkgs.wlroots_0_20.override {
    inherit libinput;

    # xwayland appears to cause issues - and not required in this context, so no harm in removing
    enableXWayland = false;
  };

  xinit' = pkgs.xinit.override (
    lib.optionalAttrs (config.services.mdevd.enable || config.services.keventd.enable) {
      xorg-server = pkgs.xorg-server.override (
        lib.optionalAttrs (config.services.mdevd.enable || config.services.keventd.enable) {
          udev = pkgs.libudev-zero;
        }
      );
    }
  );
in
{
  imports = with modules; [
    accounts-daemon
    greetd
  ];

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
          inherit wlroots_0_20;
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
    services.accounts-daemon.enable = true;
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

    finit.services.greetd.conditions = [
      "service/accounts-daemon/ready"
    ];

    programs.regreet.settings = {
      commands =
        lib.optionalAttrs config.services.seatd.enable {
          reboot = [
            config.providers.privileges.command
            "/run/current-system/sw/bin/reboot"
          ];
          poweroff = [
            config.providers.privileges.command
            "/run/current-system/sw/bin/poweroff"
          ];
        }
        // lib.optionalAttrs config.services.elogind.enable {
          reboot = [
            "loginctl"
            "reboot"
          ];
          poweroff = [
            "loginctl"
            "poweroff"
          ];
        }
        // lib.optionalAttrs config.services.xserver.enable or false {
          x11_prefix = [
            (lib.getExe' xinit' "startx")
            (lib.getExe' config.programs.coreutils.package "env")
          ];
        };
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

    finit.tmpfiles.rules = [
      "d /var/log/regreet 0755 greeter greeter - -"
      "d /var/lib/regreet 0755 greeter greeter - -"
    ];
  };
}
