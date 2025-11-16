{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.atd;
in
{
  options.services.atd = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [atd](${pkgs.at.meta.homepage}) as a system service.
      '';
    };

    extraArgs = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = ''
        Additional arguments to pass to `atd`. See {manpage}`atd(8)`
        for additional details.
      '';
    };

    allow = lib.mkOption {
      type = with lib.types; nullOr (listOf str);
      default = null;
      description = ''
        Users allowed to use `at`. See {manpage}`at.allow(5)`
        for additional details.
      '';
    };

    deny = lib.mkOption {
      type = with lib.types; nullOr (listOf str);
      default = [ ];
      description = ''
        Users who are not allowed to use `at`. See {manpage}`at.deny(5)`
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    finit.services.atd = {
      description = "deferred execution scheduler";
      conditions = "service/syslogd/ready";
      command = "${pkgs.at}/bin/atd -f " + lib.escapeShellArgs cfg.extraArgs;
      notify = "pid";
    };

    users.users = {
      atd = {
        description = "atd user";
        group = "atd";
      };
    };

    users.groups = {
      atd = { };
    };

    security.wrappers = lib.genAttrs [ "at" "atq" "atrm" ] (program: {
      source = "${pkgs.at}/bin/${program}";
      owner = "atd";
      group = "atd";
      setuid = true;
      setgid = true;
    });

    services.tmpfiles.atd.rules = [
      "d /var/spool/atjobs 1770 atd atd"
      "f /var/spool/atjobs/.SEQ 0600 atd atd"
      "d /var/spool/atspool 1770 atd atd"
    ];

    security.pam.services.atd = {
      text = ''
        # Account management.
        account required pam_unix.so # unix (order 10900)

        # Authentication management.
        auth sufficient pam_unix.so likeauth try_first_pass # unix (order 11500)
        auth required pam_deny.so # deny (order 12300)

        # Password management.
        password sufficient pam_unix.so nullok yescrypt # unix (order 10200)

        # Session management.
        session required pam_env.so conffile=/etc/security/pam_env.conf readenv=0 # env (order 10100)
        session required pam_unix.so # unix (order 10200)
      '';
    };
  };
}
