{
  lib,
  pkgs,
  config,
  modules,
  ...
}:
let
  inherit (lib) types;
  cfg = config.programs.cosmic-applets;
  udevApi =
    if config.services.gardendevd.enable then
      pkgs.libudev-garden
    else if config.services.mdevd.enable || config.services.keventd.enable then
      pkgs.libudev-zero
    else
      null;
in
{
  imports = [
    modules.pipewire
  ];

  options = {
    programs.cosmic-applets = {
      enable = lib.mkEnableOption "COSMIC applets";
      package = lib.mkOption {
        type = types.package;
        default = pkgs.cosmic-applets.override {
          udev = udevApi;
          libinput = pkgs.libinput.override (
            lib.optionalAttrs (udevApi != null) {
              udev = udevApi;
              wacomSupport = false;
            }
          );
          pipewire = config.programs.pipewire.package;
        };
        defaultText = lib.literalExpression "pkgs.cosmic-applets";
        description = ''
          The package to use for `cosmic-applets`.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
    ];
  };
}
