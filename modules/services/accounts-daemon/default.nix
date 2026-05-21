{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.accounts-daemon;
in
{
  options.services.accounts-daemon = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [accountsservice](${pkgs.accountsservice.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.accountsservice;
      defaultText = lib.literalExpression "pkgs.accountsservice";
      description = ''
        The package to use for `accountsservice`.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.pathsToLink = [ "/share/accountsservice" ];

    services.dbus.enable = true;
    services.dbus.packages = [ cfg.package ];

    finit.services.accounts-daemon = {
      description = "accounts service";
      conditions = "service/dbus/ready";
      command = "${cfg.package}/libexec/accounts-daemon" + lib.optionalString cfg.debug " --debug";
      nohup = true;
      log = true;
      environment = {
        GVFS_DISABLE_FUSE = 1;
        GIO_USE_VFS = "local";
        GVFS_REMOTE_VOLUME_MONITOR_IGNORE = 1;

        # accounts daemon looks for dbus interfaces in $XDG_DATA_DIRS/accountsservice
        XDG_DATA_DIRS = "/run/current-system/sw/share"; # "${config.system.path}/share";
      }
      //
        lib.optionalAttrs true # config.users.mutableUsers
          {
            NIXOS_USERS_PURE = "true";
          };
    };

    finit.tmpfiles.rules = [
      "d /var/lib/AccountsService 0775"
    ];
  };
}
