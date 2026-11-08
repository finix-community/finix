{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.ratbagd;

  # gardendevd needs libudev-garden; mdevd/keventd need libudev-zero
  udevApi =
    if config.services.gardendevd.enable then
      pkgs.libudev-garden
    else if config.services.mdevd.enable || config.services.keventd.enable then
      pkgs.libudev-zero
    else
      null;
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
        default =
          (pkgs.libratbag.override {
            systemd = pkgs.callPackage ./elogind/package.nix { };
            udev = udevApi;
          }).overrideAttrs
            (o: {
              mesonFlags = [
                "-Dlogind-provider=elogind"
                "-Dsystemd=false"
              ];
            });
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
