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
  imports = [
    ./accounts-daemon-dinit.nix
    ./accounts-daemon-finit.nix
  ];

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

    finit.tmpfiles.rules = [
      "d /var/lib/AccountsService 0775"
    ];
  };
}
