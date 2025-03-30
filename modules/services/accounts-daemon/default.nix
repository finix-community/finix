{ config, lib, pkgs, ... }:
{
  options.services.accounts-daemon = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable AccountsService, a DBus service for accessing
        the list of user accounts and information attached to those accounts.
      '';
    };

  };

  config = lib.mkIf config.services.accounts-daemon.enable {

    environment.systemPackages = [ pkgs.accountsservice ];

    # Accounts daemon looks for dbus interfaces in $XDG_DATA_DIRS/accountsservice
    environment.pathsToLink = [ "/share/accountsservice" ];

    services.dbus.packages = [ pkgs.accountsservice ];

    finit.services.accounts-daemon = {
      description = "accounts service";
      runlevels = "34";
      command = "${pkgs.accountsservice}/libexec/accounts-daemon";

      # environment.XDG_DATA_DIRS = "${config.system.path}/share";
      # environment.NIXOS_USERS_PURE = lib.mkIf (!config.users.mutableUsers) "true";
    };

    services.tmpfiles.accounts-daemon.rules = [
      "d /var/lib/AccountsService 0775"
      "d /var/lib/AccountsService/icons 0775"
      "d /var/lib/AccountsService/users 0700"
    ];
  };
}
