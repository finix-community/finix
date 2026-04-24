{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.services.ly;

  format = pkgs.formats.keyValue { };

  brightnessctl = config.programs.brightnessctl.package or pkgs.brightnessctl;
in
{
  options.services.ly = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [ly](${pkgs.ly.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      # TODO: drop override on next nixpkgs bump
      default = pkgs.ly.overrideAttrs (o: {
        postInstall = o.postInstall or "" + ''
          install -Dm0644 res/config.ini "$out/etc/config.ini"
          install -Dm0755 res/setup.sh "$out/etc/setup.sh"
        '';
      });
      defaultText = lib.literalExpression "pkgs.ly";
      description = ''
        The package to use for `ly`.
      '';
    };

    tty = lib.mkOption {
      type = lib.types.int;
      default = 2;
      description = "The TTY that `ly` runs on. Changing this while logged in will exit your session.";
    };

    settings = lib.mkOption {
      type = format.type;
      defaultText = lib.literalExpression "See description.";
      description = ''
        `ly` configuration. See [upstream example](https://github.com/fairyglade/ly/blob/master/res/config.ini)
        for additional details.
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
      service_name = "ly";
      waylandsessions = "/run/current-system/sw/share/wayland-sessions";

      # TODO: these scripts should be included in the nixpkgs package
      setup_cmd = lib.mkDefault "${cfg.package}/etc/setup.sh";
      # start_cmd = "";

      # defer to pam for PATH
      path = null;

      restart_cmd = "${config.finit.package}/bin/initctl reboot";
      shutdown_cmd = "${config.finit.package}/bin/initctl poweroff";
      brightness_up_cmd = lib.mkDefault "${lib.getExe brightnessctl} -q s +10%";
      brightness_down_cmd = lib.mkDefault "${lib.getExe brightnessctl} -q s 10%-";
    }
    // lib.optionalAttrs config.services.xserver.enable or false {
      xsessions = "/run/current-system/sw/share/xsessions";
      xauth_cmd = "${pkgs.xorg.xauth}/bin/xauth";

      # TODO: x_cmd
    };

    environment.etc."ly/config.ini".source = format.generate "config.ini" cfg.settings;
    environment.pathsToLink = [ "/share/ly" ];
    environment.systemPackages = [ cfg.package ];

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
      nohup = true;
      cgroup.name = "user";
    };
  };
}
