{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.ratbagd;
in
{
  options = {
    services.ratbagd = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable [ratbagd](${pkgs.libratbag.meta.homepage}) for configuring gaming mice.
        '';
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.libratbag;
        defaultText = lib.literalExpression "pkgs.libratbag";
        description = ''
          The package to use for `libratbag`.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    services.udev.packages = [ cfg.package ];

    finit.services.ratbagd = {
      description = "ratbagd";
      command = lib.getExe' cfg.package "ratbagd";
      conditions = "service/dbus/ready";
    };
  };
}
