{
  modules,
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.tuigreet;
in
{
  imports = [
    ./test.nix
    modules.greetd
  ];

  options.programs.tuigreet = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [tuigreet](${pkgs.tuigreet.meta.homepage}).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.tuigreet;
      defaultText = lib.literalExpression "pkgs.tuigreet";
      description = ''
        The package to use for `tuigreet`.
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
      default = [ "--time" ];
      description = ''
        Additional arguments to pass to `tuigreet`. See {manpage}`tuigreet(1)`
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.tuigreet.extraArgs =
      lib.optionals cfg.debug [ "--debug" ]
      ++ lib.optionals config.services.elogind.enable [
        "--power-shutdown"
        "loginctl poweroff"
        "--power-reboot"
        "loginctl reboot"
      ]
      ++ lib.optionals config.services.seatd.enable [
        "--power-shutdown"
        "${config.providers.privileges.command} /run/current-system/sw/bin/poweroff"
        "--power-reboot"
        "${config.providers.privileges.command} /run/current-system/sw/bin/reboot"
      ]
      ++ lib.optionals config.programs.xorg.enable or false [
        "--xsession-wrapper"
        "${lib.getExe' config.programs.xinit "startx"} ${lib.getExe' config.programs.coreutils.package "env"}"
      ];

    services.greetd.enable = true;
    services.greetd.settings = {
      default_session = {
        command = "${lib.getExe cfg.package} " + lib.escapeShellArgs cfg.extraArgs;
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
      "d /var/cache/tuigreet - greeter greeter - -"
    ];
  };
}
