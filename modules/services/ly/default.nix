{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.services.ly;

  configFile = pkgs.writeText "config.ini" ( lib.generators.toKeyValue {} cfg.settings );
in
{
  options.services.ly = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable ly, a lightweight TUI (ncurses-like) display manager for Linux and BSD.";
    };

    package = lib.mkPackageOption pkgs "ly" { };

    tty = lib.mkOption {
      type = lib.types.int;
      default = 2;
      description = "The TTY that ly runs on. Changing this while logged in will exit your session.";
    };

    settings = lib.mkOption {
      type = with lib.types; attrsOf (oneOf [ str int bool float ]);
      defaultText = lib.literalExpression "See description.";
      description = ''
        ly configuration written in nix. See [upstream example](https://github.com/fairyglade/ly/blob/master/res/config.ini)
        for available options.

        The following settings are set by default:
        ```
        path = "/run/current-system/sw/bin"
        service_name = "ly"
        waylandsessions = "/run/current-system/sw/share/wayland-sessions"
        xsessions = "/run/current-system/sw/share/xsessions"
        setup_cmd = "/etc/ly/setup.sh"
        ```
      '';

      example = lib.literalExpression ''
        {
          animation_frame_delay = 5 # Set delay between animation frames.
          asterisk = "*"; # Set the character used to mask the password.
          bg = "0x20000000"; # Set the background color to black in 0xSSRRGGBB format.
          bigclock_12hr = false; # Set bigclock to 12 hour format.
          battery_id = "null" # Don't show battery (e.g. on a desktop)
        }
      '';
    };
  };
  config = lib.mkIf cfg.enable {
    services.ly.settings = {
      path = lib.mkDefault "/run/current-system/sw/bin";
      service_name = lib.mkDefault "ly";
      waylandsessions = lib.mkDefault "/run/current-system/sw/share/wayland-sessions";
      xsessions = lib.mkDefault "/run/current-system/sw/share/xsessions";
      setup_cmd = lib.mkDefault "/etc/ly/setup.sh";
    };

    environment.etc."ly/config.ini".source = configFile;
    environment.etc."ly/setup.sh" = {
      source = ./setup.sh;
      mode = "0755";
    };

    environment.pathsToLink = [ "/share/ly" ];

    environment.systemPackages = [ cfg.package ];

    services.dbus.packages = [ cfg.package ];

    security.pam.services.ly.text = ''
      # Account management.
      account required pam_unix.so
      # Authentication management.
      auth optional pam_unix.so likeauth nullok
      auth sufficient pam_unix.so likeauth nullok try_first_pass
      auth required pam_deny.so
      # Password management.
      password sufficient pam_unix.so nullok yescrypt
      # Session management.
      session required pam_env.so debug conffile=/etc/security/pam_env.conf readenv=1
      session required pam_unix.so
      session optional pam_loginuid.so
      ${lib.optionalString config.services.elogind.enable "session optional ${pkgs.elogind}/lib/security/pam_elogind.so"}
      ${lib.optionalString config.services.seatd.enable "session optional ${pkgs.pam_rundir}/lib/security/pam_rundir.so"}
      session required ${config.security.pam.package}/lib/security/pam_lastlog.so silent
    '';

    # Disable the tty that ly runs on
    finit.ttys."tty${toString cfg.tty}".enable = false;

    finit.services.ly = {
      description = "ly terminal display/login manager";
      runlevels = "34";
      conditions = [
        "service/syslogd/ready"
      ]
      ++ lib.optionals config.services.elogind.enable [ "service/elogind/ready" ]
      ++ lib.optionals config.services.seatd.enable [ "service/seatd/ready" ];
      command = "${pkgs.util-linux}/bin/agetty -nil ${cfg.package}/bin/ly tty${toString cfg.tty}";
      cgroup.name = "user";
    };
  };
}
