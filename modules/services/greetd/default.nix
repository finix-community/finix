{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.greetd;
  format = pkgs.formats.toml { };

  configFile = format.generate "greetd.toml" cfg.settings;

  session_rundir =
    if config.services.sessiond.enable then
      "${config.services.sessiond.package}/lib/security/pam_sessiond.so"
    else if config.services.elogind.enable then
      "${pkgs.elogind}/lib/security/pam_elogind.so"
    else if config.services.seatd.enable then
      "${pkgs.pam_rundir}/lib/security/pam_rundir.so"
    else
      null;
in
{
  options.services.greetd = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [greetd](${pkgs.greetd.meta.homepage}) as a system service.
      '';
    };

    settings = lib.mkOption {
      inherit (format) type;
      default = { };
      description = ''
        `greetd` configuration. See {manpage}`greetd(5)`
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.greetd.settings = {
      terminal.vt = lib.mkDefault "next";
      default_session = {
        command = lib.mkDefault "${pkgs.greetd}/bin/agreety";
        user = "greeter";
      };
    };

    finit.services.greetd = {
      description = "greeter daemon";
      runlevel = "34";
      conditions = [
        "service/syslogd/ready"
      ]
      ++ lib.optionals config.services.sessiond.enable [ "service/sessiond/ready" ]
      ++ lib.optionals config.services.elogind.enable [ "service/elogind/ready" ]
      ++ lib.optionals config.services.seatd.enable [ "service/seatd/ready" ];
      command = "${pkgs.greetd}/bin/greetd --config ${configFile}";
      cgroup.user = { };
    };

    users.users = {
      greeter = {
        isSystemUser = true;
        group = "greeter";
        extraGroups = [
          "video"
        ]
        ++ lib.optionals config.services.elogind.enable [
          "render"
        ]
        ++ lib.optionals config.services.seatd.enable [
          config.services.seatd.group
        ];
      };
    };

    users.groups = {
      greeter = { };
    };

    finit.tmpfiles.rules = [
      "d /var/cache/tuigreet - greeter greeter"
    ];

    security.pam = {
      enable = true;
      services.greetd.rules = {
        account.unix = {
          order = 10900;
          control = "required";
          modulePath = "pam_unix.so";
        };

        auth = {
          unix = {
            order = 12800;
            control = "sufficient";
            modulePath = "pam_unix.so";
            settings = {
              likeauth = true;
              nullok = true;
              try_first_pass = true;
            };
          };
          deny = {
            order = 13600;
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
          loginuid = {
            order = 10300;
            control = "required";
            modulePath = "pam_loginuid.so";
          };
          limits = {
            order = 10400;
            control = "required";
            modulePath = "pam_limits.so";
          };
          lastlog = {
            order = 10700;
            control = "required";
            modulePath = "${pkgs.util-linux.lastlog}/lib/security/pam_lastlog2.so";
            settings.silent = true;
          };
          rundir = lib.mkIf (session_rundir != null) {
            order = 12000;
            control = "optional";
            modulePath = session_rundir;
          };
        };
      };
    };

  };
}
