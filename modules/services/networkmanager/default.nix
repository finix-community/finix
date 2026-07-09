{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.networkmanager;

  packages = [
    cfg.package
    pkgs.wpa_supplicant
  ];
in
{
  imports = [ ./test.nix ];

  options.services.networkmanager = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [networkmanager](${pkgs.networkmanager.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.networkmanager;
      defaultText = lib.literalExpression "pkgs.networkmanager";
      description = ''
        The package to use for `networkmanager`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelModules = [
      "ctr"
    ];

    environment.systemPackages = packages;

    services.dbus.enable = true;
    services.dbus.packages = packages;
    services.udev.packages = packages;

    # nixpkgs builds NetworkManager with a hardcoded resolvconf path, so the
    # default rc-manager=auto always selects resolvconf, even when nothing
    # has set it up, silently dropping DNS updates.
    environment.etc."NetworkManager/conf.d/00-nixos.conf".text = lib.generators.toINI { } {
      main.rc-manager = if config.programs.resolvconf.enable then "resolvconf" else "symlink";
    };

    finit.services.network-manager = {
      description = "network manager service";
      conditions = "service/dbus/ready";
      command = "${cfg.package}/bin/NetworkManager -n";
    };

    users.groups = {
      networkmanager.gid = config.ids.gids.networkmanager;
    };
  };
}
