{ config, pkgs, lib, ... }:
let
  cfg = config.services.greetd;
  format = pkgs.formats.toml { };

  configFile = format.generate "greetd.toml" cfg.settings;
in
{
  options.services.greetd = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    settings = lib.mkOption {
      type = format.type;
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    services.greetd.settings = {
      terminal.vt = 7;
      default_session = {
        user = "greeter";
      };
    };

    finit.services.greetd = {
      description = "greeter daemon";
      runlevels = "34";
      conditions = [ "service/syslogd/ready" ] ++ lib.optionals config.services.seatd.enable [ "service/seatd/ready" ];
      command = "${pkgs.greetd.greetd}/bin/greetd --config ${configFile}";
      cgroup.name = "user";
    };

    users.users = {
      greeter = {
        isSystemUser = true;
        group = "greeter";
        extraGroups = lib.optionals config.services.seatd.enable [
          config.services.seatd.group
          "video"
        ];
      };
    };

    users.groups = {
      greeter = { };
    };

    services.tmpfiles.greetd.rules = [
      "d /var/cache/tuigreet - greeter greeter"
    ];

    # pulled from lemurs
    security.pam.services.greetd = {
      text = ''
        # Account management.
        account required pam_unix.so # unix (order 10900)

        # Authentication management.
        auth optional pam_unix.so likeauth nullok # unix-early (order 11500)
        auth sufficient pam_unix.so likeauth nullok try_first_pass # unix (order 12800)
        auth required pam_deny.so # deny (order 13600)

        # Password management.
        password sufficient pam_unix.so nullok yescrypt # unix (order 10200)

        # Session management.
        session required pam_env.so conffile=/etc/pam/environment readenv=1 debug # env (order 10100)
        session required pam_unix.so # unix (order 10200)
        # https://github.com/coastalwhite/lemurs/issues/166
        # session optional pam_loginuid.so # loginuid (order 10300)

        ${lib.optionalString config.services.elogind.enable "session optional ${pkgs.elogind}/lib/security/pam_elogind.so"}
        ${lib.optionalString config.services.seatd.enable "session optional ${pkgs.pam_rundir}/lib/security/pam_rundir.so"}

        session required ${pkgs.linux-pam}/lib/security/pam_lastlog.so silent # lastlog (order 10700)
      '';
    };
  };
}
