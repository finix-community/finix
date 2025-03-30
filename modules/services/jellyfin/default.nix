{ config, pkgs, lib, ... }:
let
  cfg = config.services.jellyfin;
in
{
  options.services.jellyfin = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.jellyfin;
    };
  };

  config = lib.mkIf cfg.enable {
    finit.services.jellyfin = {
      description = "jellyfin media server";
      conditions = "service/syslogd/ready";
      command = "${lib.getExe cfg.package} --datadir /var/lib/jellyfin --configdir /var/lib/jellyfin/config --cachedir /var/cache/jellyfin --logdir /var/log/jellyfin";
      user = "jellyfin";
      group = "jellyfin";
    };

    services.tmpfiles.jellyfin.rules = [
      "d /var/cache/jellyfin 0700 jellyfin jellyfin"
      "d /var/lib/jellyfin 0700 jellyfin jellyfin"
      "d /var/lib/jellyfin/config 0700 jellyfin jellyfin"
      "d /var/log/jellyfin 0750 jellyfin jellyfin"
    ];

    users.users = {
      jellyfin = {
        group = "jellyfin";
        isSystemUser = true;
      };
    };

    users.groups = {
      jellyfin = { };
    };
  };
}
