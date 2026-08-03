{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.turnstile;
in
{
  options.services.turnstile = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [turnstilel](${cfg.package.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.turnstile.override {
        dinitSupport = cfg.dinit.enable;
        runitSupport = cfg.runit.enable;
      };
      description = ''
        The package to use for `turnstile`.
      '';
    };

    settings = {
      debug = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to output debug information. This is verbose
          logging that is only useful when investigating issues.
        '';
      };

      backend = lib.mkOption {
        type = lib.types.enum [
          "none"
          "dinit"
          "runit"
        ];
        default = "none";
        description = ''
          The service backend to use.

          See {manpage}`turnstiled.conf(5)` for additional details.
        '';
      };

      debug_stderr = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to print debug messages also to `stderr`.
        '';
      };

      linger = lib.mkOption {
        type = with lib.types; either bool (enum [ "maybe" ]);
        default = "maybe";
        description = ''
          Whether to keep already started services running even
          after the last login of the user is gone.

          See {manpage}`turnstiled.conf(5)` for additional details.
        '';
      };

      rundir_path = lib.mkOption {
        type = lib.types.str;
        default = "/run/user/%u";
        description = ''
          The value of `XDG_RUNTIME_DIR` that is exported into the
          user service environment.

          See {manpage}`turnstiled.conf(5)` for additional details.
        '';
      };

      manage_rundir = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to manage the `XDG_RUNTIME_DIR`.

          See {manpage}`turnstiled.conf(5)` for additional details.
        '';
      };

      export_dbus_address = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to export `DBUS_SESSION_BUS_ADDRESS` into the
          environment.

          See {manpage}`turnstiled.conf(5)` for additional details.
        '';
      };

      login_timeout = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 60;
        description = ''
          The timeout for the login.

          See {manpage}`turnstiled.conf(5)` for additional details.
        '';
      };

      root_session = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          When using a backend that is not `none`, this controls
          whether to run the user session manager for the `root`
          user. The login session will still be tracked regardless
          of the setting,
        '';
      };
    };

    dinit = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether or not to use the dinit backend for `turnstile`.
        '';
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.dinit;
        defaultText = lib.literalExpression "pkgs.dinit";
        description = ''
          # TODO:
        '';
      };

      settings = {
        boot_dir = lib.mkOption {
          type = with lib.types; either path str;
          default = "\${HOME}/.config/dinit.d/boot.d";
          description = ''
            The directory containing service links that must be
            started in order for the login to proceed. Can be
            empty, in which case nothing is waited for.
          '';
        };

        system_boot_dir = lib.mkOption {
          type = with lib.types; either path str;
          default = "/etc/dinit.d/user/boot.d";
          description = ''
            This is just like boot_dir, but not controlled by the
            user. Instead, the system installs links there, and
            they are started for all users universally.
          '';
        };

        services_dir = lib.mkOption {
          type = with lib.types; listOf (either path str);
          default = [ "\${HOME}/.config/dinit.d" ];
          description = ''
            A directory user service files are read from. Every
            additional directory needs to have its number incremented.
            The numbering matters (defines the order) and there must be
            no gaps (it starts with 1, ends at the last undefined).
          '';
        };
      };
    };

    runit = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether or not to use the runit backend for `turnstile`.
        '';
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.runit;
        defaultText = lib.literalExpression "pkgs.runit";
        description = ''
          # TODO:
        '';
      };

      settings = {
        ready_sv = lib.mkOption {
          type = with lib.types; str;
          default = "turnstile-ready";
          description = ''
            The name of the service that turnstile will check for login readiness
          '';
        };

        services_dir = lib.mkOption {
          type = with lib.types; either path str;
          default = "\${HOME}/.config/service";
          description = ''
            The directory user service files are read from. Can include a way to differentiate between users, like `$HOME`.
          '';
        };

        service_env_dir = lib.mkOption {
          type = with lib.types; either path str;
          default = "\${HOME}/.config/service-env";
          description = ''
            The environment variable directory user service files can read from. Can include a way to differentiate between users, like `$HOME`.
          '';
        };
      };
    };
  };

  # extend finit.ttys to add turnstile readiness conditions
  options.finit = {
    ttys = lib.mkOption {
      type =
        with lib.types;
        attrsOf (submodule {
          config = lib.mkIf cfg.enable {
            conditions = "usr/turnstiled-start";
          };
        });
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
    ]
    ++ lib.optionals cfg.dinit.enable [ (lib.lowPrio cfg.dinit.package) ]
    ++ lib.optionals cfg.runit.enable [ (lib.lowPrio cfg.runit.package) ];

    environment.etc = {
      "turnstile/turnstiled.conf".source =
        let
          format = pkgs.formats.keyValue {
            mkKeyValue = lib.generators.mkKeyValueDefault {
              mkValueString =
                v:
                if v == true then
                  "yes"
                else if v == false then
                  "no"
                else
                  lib.generators.mkValueStringDefault { } v;
            } " = ";
          };
        in
        format.generate "turnstiled.conf" cfg.settings;
    }
    // lib.optionalAttrs cfg.dinit.enable {
      "turnstile/backend/dinit.conf".source =
        let
          format = pkgs.formats.keyValue {
            mkKeyValue = lib.generators.mkKeyValueDefault {
              mkValueString = v: "\"" + lib.generators.mkValueStringDefault { } v + "\"";
            } "=";
          };
        in
        format.generate "dinit.conf" (
          {
            inherit (cfg.dinit.settings) boot_dir system_boot_dir;
          }
          // (lib.listToAttrs (
            lib.imap1 (i: v: lib.nameValuePair "services_dir${toString i}" v) cfg.dinit.settings.services_dir
          ))
        );
    }
    // lib.optionalAttrs cfg.runit.enable {
      "turnstile/backend/runit.conf".source =
        let
          format = pkgs.formats.keyValue {
            mkKeyValue = lib.generators.mkKeyValueDefault {
              mkValueString = v: "\"" + lib.generators.mkValueStringDefault { } v + "\"";
            } "=";
          };
        in
        format.generate "runit.conf" {
          inherit (cfg.runit.settings) ready_sv services_dir service_env_dir;
        };
    };

    security.pam.services = {
      login.text = lib.mkAfter "session optional ${cfg.package}/lib/security/pam_turnstile.so";

      turnstiled.text = ''
        # Authentication management.
        auth sufficient pam_rootok.so # rootok (order 10200)

        # Session management.
        session optional pam_keyinit.so force revoke
        session optional pam_umask.so usergroups umask=022
        ${lib.optionalString config.services.elogind.enable "session optional ${pkgs.elogind}/lib/security/pam_elogind.so"}
        session required pam_env.so conffile=/etc/security/pam_env.conf readenv=0 # env (order 10100)
        session required ${cfg.package}/lib/security/pam_turnstile.so turnstiled
        session required pam_limits.so
      '';
    };

    finit.services.turnstiled = {
      description = "turnstiled, a user-service manager manager";
      command = "${lib.getExe cfg.package} ${config.environment.etc."turnstile/turnstiled.conf".source}";
      conditions = "service/syslogd/ready";
      pre = pkgs.writeShellScript "turnstiled-start" ''
        ${lib.getExe' config.finit.package "initctl"} cond set usr/turnstiled-start
      '';
      log = true;
      path = [
        cfg.package
        config.programs.coreutils.package
      ]
      ++ lib.optionals cfg.dinit.enable [ cfg.dinit.package ]
      ++ lib.optionals cfg.runit.enable [ cfg.runit.package ];
    };
  };
}
