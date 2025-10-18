{ config, pkgs, lib, ... }:
let
  cfg = config.services.networkmanager;

  packages = [
    cfg.package
    pkgs.wpa_supplicant
  ];
in
{
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

    services.dbus.packages = packages;
    services.udev.packages = packages;

    finit.services.network-manager = {
      description = "network manager service";
      conditions = "service/syslogd/ready";
      command = "${cfg.package}/bin/NetworkManager -n";
    };

    users.groups = {
      networkmanager.gid = config.ids.gids.networkmanager;
    };
  };
}
