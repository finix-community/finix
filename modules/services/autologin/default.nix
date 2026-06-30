{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.autologin;
in
{
  options.services.autologin = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [autologin](${pkgs.autologin.meta.homepage}) as a system service.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      description = ''
        User account under which `autologin` runs.

        ::: {.note}
        You are responsible for ensuring the user exists before the `autologin` service starts.
        :::
      '';
    };

    command = lib.mkOption {
      type = lib.types.path;
      description = ''
        Command to execute once {option}`user` is logged in on `tty1`.
      '';
      example = lib.literalExpression ''
        pkgs.writeShellScript "autologin.sh" '''
          exec ''${pkgs.dbus}/bin/dbus-run-session -- ''${lib.getExe pkgs.labwc}
        '''
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    security.pam.services.autologin = {
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
        session required pam_env.so conffile=/etc/security/pam_env.conf readenv=0 # env (order 10100)
        session required pam_unix.so # unix (order 10200)
        session required pam_loginuid.so # loginuid (order 10300)
        session required ${config.security.pam.package}/lib/security/pam_lastlog.so silent # lastlog (order 10700)

        ${lib.optionalString config.services.elogind.enable "session optional ${pkgs.elogind}/lib/security/pam_elogind.so"}
        ${lib.optionalString config.services.seatd.enable "session optional ${pkgs.pam_rundir}/lib/security/pam_rundir.so"}
        session required pam_limits.so
      '';
    };

    # autologin is hardcoded to run on tty1
    finit.ttys.tty1.enable = lib.mkForce false;

    finit.services.autologin = {
      command = "${lib.getExe pkgs.autologin} ${cfg.user} ${cfg.command}";
      conditions = [
        "service/syslogd/ready"
      ]
      ++ lib.optionals config.services.elogind.enable [ "service/elogind/ready" ]
      ++ lib.optionals config.services.seatd.enable [ "service/seatd/ready" ];
      log = true;
      nohup = true;
      cgroup.name = "user";
      tty = lib.mkForce "/dev/tty1";
    };
  };
}
