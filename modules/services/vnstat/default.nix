{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.vnstat;
in
{
  options.services.vnstat = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [vnstat](${pkgs.vnstat.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.vnstat;
      defaultText = lib.literalExpression "pkgs.vnstat";
      description = ''
        The package to use for `vnstat`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    users = {
      groups.vnstatd = { };

      users.vnstatd = {
        isSystemUser = true;
        group = "vnstatd";
        description = "vnstat daemon user";
      };
    };

    finit.services.vnstat = {
      description = "vnStat network traffic monitor";
      command = "${pkgs.vnstat}/bin/vnstatd -n";
      path = [ pkgs.coreutils ];

      group = "vnstatd";
      user = "vnstatd";
    };
  };
}
