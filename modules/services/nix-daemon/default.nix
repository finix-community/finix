{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.nix-daemon;
in
{
  options.services.nix-daemon = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [nix](${pkgs.nix.meta.homepage}) as a system service.

        ::: {.warning}
        Disabling `nix` makes the system hard to modify and the Nix programs and configuration will not be made available by NixOS itself.
        :::
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = config.programs.nix.package;
      defaultText = lib.literalExpression "config.programs.nix.package";
      description = ''
        The package to use for `nix`.
      '';
    };

    nrBuildUsers = lib.mkOption {
      type = lib.types.int;
      default = 8;
      description = ''
        Number of `nixbld` user accounts created to
        perform secure concurrent builds.  If you receive an error
        message saying that "all build users are currently in use",
        you should increase this value.
      '';
    };

  };
  config = lib.mkIf cfg.enable {
    finit.services.nix-daemon = {
      description = "nix daemon";
      conditions = "service/syslogd/ready";
      command = "${cfg.package}/bin/nix-daemon --daemon";
      nohup = true;

      environment.CURL_CA_BUNDLE = config.security.pki.caBundle;

      # https://github.com/NixOS/nix/blob/81884c36a381737a438ddc5decb658446074d064/misc/systemd/nix-daemon.service.in#L12-L13
      cgroup.settings."pids.max" = 1048576;
      rlimits.nofile = 1048576;
    };

    environment.systemPackages = lib.optional (cfg.package != config.programs.nix.package) cfg.package;

    finit.tmpfiles.rules = [
      "d /nix/var/nix/daemon-socket 0755 root root - -"
    ];

    users.users = lib.listToAttrs (
      map (nr: {
        name = "nixbld${toString nr}";
        value = {
          description = "Nix build user ${toString nr}";
          uid = builtins.add config.ids.uids.nixbld nr;
          group = "nixbld";
          extraGroups = [ "nixbld" ];
        };
      }) (lib.range 1 cfg.nrBuildUsers)
    );

    users.groups = {
      nixbld.gid = config.ids.gids.nixbld;
    };

    # TODO: add finit.services.restartTriggers option
    environment.etc."finit.d/nix-daemon.conf".text = lib.mkAfter ''

      # standard nixos trick to force a restart when something has changed
      # ${config.environment.etc."nix/nix.conf".source}
    '';
  };
}
