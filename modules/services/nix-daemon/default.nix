{ config, pkgs, lib, ... }:
let
  cfg = config.services.nix-daemon;
in
{
  options.services.nix-daemon = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable Nix.
        Disabling Nix makes the system hard to modify and the Nix programs and configuration will not be made available by NixOS itself.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nix;
      defaultText = lib.literalExpression "pkgs.nix";
      description = ''
        This option specifies the Nix package instance to use throughout the system.
      '';
    };

    nrBuildUsers = lib.mkOption {
      type = lib.types.int;
      description = ''
        Number of `nixbld` user accounts created to
        perform secure concurrent builds.  If you receive an error
        message saying that “all build users are currently in use”,
        you should increase this value.
      '';

      # TODO: set this based on nix.settings
      default = 8;
    };
  };

  config = lib.mkIf cfg.enable {
    finit.services.nix-daemon = {
      description = "nix daemon";
      conditions = "service/syslogd/ready";
      command = "${cfg.package}/bin/nix-daemon --daemon";
    };

    environment.systemPackages = [
      cfg.package
    ];

    services.tmpfiles.nix-daemon.rules = [
      "d /nix/var/nix/daemon-socket 0755 root root - -"

      "R! /nix/var/nix/gcroots/tmp           -    -    -    - -"
      "R! /nix/var/nix/temproots             -    -    -    - -"

      "d  /nix/var                           0755 root root - -"
      "L+ /nix/var/nix/gcroots/booted-system 0755 root root - /run/booted-system"

      # Prevent the current configuration from being garbage-collected.
      "d /nix/var/nix/gcroots -"
      "L+ /nix/var/nix/gcroots/current-system - - - - /run/current-system"
    ];

    users.users = lib.listToAttrs (map (nr: {
      name = "nixbld${toString nr}";
      value = {
        description = "Nix build user ${toString nr}";
        uid = builtins.add config.ids.uids.nixbld nr;
        group = "nixbld";
        extraGroups = [ "nixbld" ];
      };
    }) (lib.range 1 32));

    users.groups = {
      nixbld.gid = config.ids.gids.nixbld;
    };

    environment.etc."nix/nix.conf".text = ''
      allowed-users = *
      auto-optimise-store = true
      experimental-features = flakes nix-command
      fallback = true
      log-lines = 25
      max-jobs = auto
      require-sigs = true
      sandbox = true
      sandbox-fallback = false
      substituters = https://cache.nixos.org/
      system-features = nixos-test benchmark big-parallel kvm
      trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
      trusted-substituters =
      trusted-users = root
      warn-dirty = false
    '';
  };
}
