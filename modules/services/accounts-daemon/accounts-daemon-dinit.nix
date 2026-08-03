{
  config,
  lib,
  ...
}:
let
  cfg = config.services.accounts-daemon;
in
{
  config = lib.mkIf cfg.enable {
    dinit.services.accounts-daemon = {
      type = "process";
      command = "${cfg.package}/libexec/accounts-daemon" + lib.optionalString cfg.debug " --debug";
      waits-for = [ "dbus" ];
      restart = true;
      smooth-recovery = true;
      targets = [ "local" ];
      environment = {
        GVFS_DISABLE_FUSE = 1;
        GIO_USE_VFS = "local";
        GVFS_REMOTE_VOLUME_MONITOR_IGNORE = 1;
        XDG_DATA_DIRS = "/run/current-system/sw/share";
        NIXOS_USERS_PURE = "true";
      };
    };
  };
}
