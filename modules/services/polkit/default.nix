{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.polkit;
in
{
  options.services.polkit = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [polkit](${pkgs.polkit.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.polkit;
      defaultText = lib.literalExpression "pkgs.polkit";
      description = ''
        The package to use for `polkit`.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.

        ::: {.note}
        This is required in order to see log messages from rule definitions.
        :::
      '';
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      example = ''
        /* Log authorization checks. */
        polkit.addRule(function(action, subject) {
          // Make sure to set { services.polkit.debug = true; } in configuration.nix
          polkit.log("user " +  subject.user + " is attempting action " + action.id + " from PID " + subject.pid);
        });

        /* Allow any local user to do anything (dangerous!). */
        polkit.addRule(function(action, subject) {
          if (subject.local) return "yes";
        });
      '';
      description = ''
        Any polkit rules to be added to config (in JavaScript ;-). See:
        <https://www.freedesktop.org/software/polkit/docs/latest/polkit.8.html#polkit-rules>
      '';
    };

    adminIdentities = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "unix-group:wheel" ];
      example = [
        "unix-user:alice"
        "unix-group:admin"
      ];
      description = ''
        Specifies which users are considered “administrators”, for those
        actions that require the user to authenticate as an
        administrator (i.e. have an `auth_admin`
        value).  By default, this is all users in the `wheel` group.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = lib.optionals config.services.sessiond.enable [
      {
        assertion = pkgs.polkit.override.__functionArgs ? useConsoleKit;
        message = "services.polkit.package is trying to use a feature which doesn't yet exist in your version of polkit - sessiond support; please try updating your nixpkgs source";
      }
    ];

    services.polkit.package = lib.mkMerge [
      (lib.mkIf config.services.sessiond.enable (
        pkgs.polkit.override {
          useConsoleKit = true;
          useSystemd = false;
        }
      ))

      # NOTE: package override required for `loginctl poweroff` to work with elogind
      (lib.mkIf config.services.elogind.enable (pkgs.polkit.override { useSystemd = false; }))
    ];

    environment.systemPackages = [
      cfg.package.bin
      cfg.package.out
    ];

    finit.services.polkit = {
      description = "policykit authorization manager";
      conditions = [
        "service/dbus/ready"
      ]
      ++ lib.optionals config.services.sessiond.enable [ "service/sessiond/ready" ];
      command =
        "${cfg.package.out}/lib/polkit-1/polkitd --no-debug "
        + lib.optionalString cfg.debug "--log-level=debug";
    };

    # The polkit daemon reads action/rule files
    environment.pathsToLink = [ "/share/polkit-1" ];

    # PolKit rules for NixOS.
    environment.etc."polkit-1/rules.d/10-nixos.rules".text = ''
      polkit.addAdminRule(function(action, subject) {
        return [${lib.concatStringsSep ", " (map (i: "\"${i}\"") cfg.adminIdentities)}];
      });

      ${cfg.extraConfig}
    ''; # TODO: validation on compilation (at least against typos)

    services.dbus.enable = true;
    services.dbus.packages = [ cfg.package.out ];

    security.pam.services.polkit-1.rules = {
      account.unix = {
        order = 10900;
        control = "required";
        modulePath = "pam_unix.so";
      };

      auth = {
        unix = {
          order = 11600;
          control = "sufficient";
          modulePath = "pam_unix.so";
          settings = {
            likeauth = true;
            try_first_pass = true;
          };
        };
        deny = {
          order = 12400;
          control = "required";
          modulePath = "pam_deny.so";
        };
      };

      password.unix = {
        order = 10200;
        control = "sufficient";
        modulePath = "pam_unix.so";
        settings = {
          nullok = true;
          yescrypt = true;
        };
      };

      session = {
        env = {
          order = 10100;
          control = "required";
          modulePath = "pam_env.so";
          settings = {
            conffile = "/etc/security/pam_env.conf";
            readenv = 0;
          };
        };
        unix = {
          order = 10200;
          control = "required";
          modulePath = "pam_unix.so";
        };
        limits = {
          order = 12200;
          control = "required";
          modulePath = "pam_limits.so";
        };
      };
    };

    security.wrappers = {
      pkexec = {
        setuid = true;
        owner = "root";
        group = "root";
        source = "${cfg.package.bin}/bin/pkexec";
      };
      polkit-agent-helper-1 = {
        setuid = true;
        owner = "root";
        group = "root";
        source = "${cfg.package.out}/lib/polkit-1/polkit-agent-helper-1";
      };
    };

    users.users.polkituser = {
      description = "PolKit daemon";
      uid = config.ids.uids.polkituser;
      group = "polkituser";
    };

    users.groups.polkituser = { };
  };
}
