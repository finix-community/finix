{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.programs.cosmic-term;
  inherit (lib) types;
  udevApi =
    if config.services.gardendevd.enable then
      pkgs.libudev-garden
    else if config.services.mdevd.enable || config.services.keventd.enable then
      pkgs.libudev-zero
    else
      null;
in
{
  options.programs.cosmic-term = {
    enable = lib.mkEnableOption "COSMIC term";
    package = lib.mkOption {
      type = types.package;
      default = pkgs.cosmic-term.override {
        libinput = pkgs.libinput.override (
          lib.optionalAttrs (udevApi != null) {
            udev = udevApi;
            wacomSupport = false;
          }
        );
      };
      defaultText = lib.literalExpression "pkgs.cosmic-term";
      description = ''
        The package to use for `cosmic-term`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
    ];
  };
}
