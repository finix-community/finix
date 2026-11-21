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
      "session optional ${config.services.sessiond.package}/lib/security/pam_sessiond.so"
    else if config.services.elogind.enable then
      "session optional ${pkgs.elogind}/lib/security/pam_elogind.so"
    else if config.services.seatd.enable then
      "session optional ${pkgs.pam_rundir}/lib/security/pam_rundir.so"
    else
      false;

  gnome-keyring = config.programs.gnome-keyring.enable or false;

  fprintd = config.services.fprintd.enable or false;
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
      services.greetd.text = ''
        # Account management.
        account required pam_unix.so # unix (order 10900)

        # Authentication management.
        ${lib.optionalString fprintd "auth sufficient ${config.services.fprintd.package}/lib/security/pam_fprintd.so"}
        auth optional pam_unix.so likeauth nullok # unix-early (order 11500)
        ${lib.optionalString gnome-keyring "auth optional ${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so"}
        auth sufficient pam_unix.so likeauth nullok try_first_pass # unix (order 12800)
        auth required pam_deny.so # deny (order 13600)

        # Password management.
        password sufficient pam_unix.so nullok yescrypt # unix (order 10200)

        # Session management.
        session required pam_env.so conffile=/etc/security/pam_env.conf readenv=0 # env (order 10100)
        session required pam_unix.so # unix (order 10200)
        session required pam_loginuid.so # loginuid (order 10300)
        session required pam_limits.so
        session required ${pkgs.util-linux.lastlog}/lib/security/pam_lastlog2.so silent # lastlog (order 10700)

        ${lib.optionalString (session_rundir != false) session_rundir}
        ${lib.optionalString gnome-keyring "session optional ${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so auto_start"}
      '';
    };

  };
}
