{
  config,
  lib,
  pkgs,
  modules,
  ...
}:
let
  cfg = config.profiles.minimal;
in
{
  imports = with modules; [
    ash
    bash
    fish
    iwd
    dhcpcd
    iwd
    networkmanager
    nftables
    getty
    nix-daemon
    sysklogd
    sessiond-uaccess
  ];

  options.profiles.minimal = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable the `minimal` profile. This profile provides
        a set of user-overrideable defaults that guarantees a 
        minimal, working system even through breaking changes in `finix`.

        ::: {.warning}
        Disabling this profile is only recommended for advanced users who 
        have a full understanding of how they want to configure their system and
        who are able to keep up with any breaking changes in `finix`.
        :::
      '';
    };

    deviceManager = lib.mkOption {
      type = lib.types.enum [
        "keventd"
        "mdevd"
        "udev"
        "gardendevd"
      ];
      default = "keventd";
      description = ''
        The device manager to use for this system. Available options include:

        - `udev`  — full-featured, matches the rest of the nix ecosystem. broadest compatibility
        - `mdevd` — lighter, from the skarnet/s6 family
        - `keventd` — brand new, finit-native udev compatible device manager (default)
        - `gardendevd` — brand new, udev rule compatible device manager
      '';
    };

    suBackend = lib.mkOption {
      type = lib.types.enum [
        "sudo"
        "doas"
      ];
      default = "doas";
      description = ''
        The backend to use for superuser privilege escalation.
      '';
    };

    networking = {
      dhcpcd.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to enable wired networking support through `dhcpcd`.
        '';
      };

      iwd.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable wireless networking support through `iwd`.
        '';
      };

      networkmanager.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable NetworkManager. Requires `udev` to be enabled. If using
          seatd, requires your user to be a member of the `networkmanager` group.
        '';
      };

      firewall.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable the `nftables` firewall.
        '';
      };
    };

    sessionTracker = lib.mkOption {
      type = lib.types.enum [
        "seatd"
        "sessiond"
        "elogind"
        "none"
      ];
      default = "none";
      description = ''
        The session tracker backend to enable. Available options include:

        - `seatd` - seat management daemon, requires additional configuration for power actions and other desktop related operations. ideal for minimal wayland compositors
        - `sessiond` - a brand new, near drop-in replacement for `elogind` utilizing the abandoned `consoleKit` dbus API as a polkit substitution. requires seatd to manage seats 
        - `elogind` - sytemd's `logind` forked into an independent project that does not require systemd to function 
        - `none` - no session tracker
      '';
    };

    shell = lib.mkOption {
      type = lib.types.enum [
        "ash"
        "bash"
        "fish"
        "dash"
      ];
      default = "ash";
      description = ''
        The system shell to enable. Available options include:

        - `ash` - busybox shell, fully POSIX-compliant (default)
        - `bash` - bourne again shell, backwards POSIX-compatible with new non-POSIX syntax
        - `dash` - fully POSIX-compliant
        - `fish` - non POSIX compatible
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.nixos-rebuild-ng
    ];

    # --- CORE PROGRAMS ---
    programs.ash.enable = lib.mkDefault (cfg.shell == "ash");
    programs.bash.enable = lib.mkDefault (cfg.shell == "bash");
    programs.fish.enable = lib.mkDefault (cfg.shell == "fish");
    # dash is already default system shell

    programs.${cfg.suBackend}.enable = lib.mkDefault true;

    # --- CORE SERVICES ---
    services.getty.enable = lib.mkDefault true;
    services.sysklogd.enable = lib.mkDefault true;
    services.${cfg.deviceManager}.enable = lib.mkDefault true;
    services.nix-daemon.enable = lib.mkDefault true;
    services.nix-daemon.settings = lib.mkDefault {
      trusted-users = lib.mkIf config.programs.sudo.enable [
        "root"
        "@wheel"
      ];
    };

    # --- NETWORKING ---
    # dhcpcd and networkmanager will conflict if both are enabled
    services.dhcpcd.enable = lib.mkDefault (
      !cfg.networking.networkmanager.enable && cfg.networking.dhcpcd.enable
    );
    services.networkmanager.enable = lib.mkDefault cfg.networking.networkmanager.enable;
    services.nftables.enable = lib.mkDefault cfg.networking.firewall.enable;
    services.iwd.enable = lib.mkDefault cfg.networking.iwd.enable;

    # --- USER SESSIONS ---
    services.seatd.enable = lib.mkDefault (
      cfg.sessionTracker == "seatd" || cfg.sessionTracker == "sessiond"
    );
    services.sessiond.enable = lib.mkDefault (cfg.sessionTracker == "sessiond");
    services.sessiond-uaccess.enable = lib.mkDefault (cfg.sessionTracker == "sessiond");
    services.elogind.enable = lib.mkDefault (cfg.sessionTracker == "elogind");
  };
}
