{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.programs.cosmic-edit;
  udevApi =
    if config.services.gardendevd.enable then
      pkgs.libudev-garden
    else if config.services.mdevd.enable || config.services.keventd.enable then
      pkgs.libudev-zero
    else
      null;
  libinput = pkgs.libinput.override (
    lib.optionalAttrs (udevApi != null) {
      udev = udevApi;
      wacomSupport = false;
    }
  );
in
{
  options.programs.cosmic-edit = {
    enable = lib.mkEnableOption "COSMIC edit";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.cosmic-edit.override { inherit libinput; };
      defaultText = lib.literalExpression "pkgs.cosmic-edit";
      description = ''
        The package to use for `cosmic-edit`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
