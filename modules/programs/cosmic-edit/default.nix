{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.programs.cosmic-edit;
  inherit (lib) types;
  udevApi =
    if config.services.gardendevd.enable then
      pkgs.libudev-garden
    else if config.services.mdevd.enable || config.services.keventd.enable then
      pkgs.libudev-zero
    else
      null;
  libinput = pkgs.libinput.override {
    udev = udevApi;
    wacomSupport = false;
  };
in
{
  options.programs.cosmic-edit = {
    enable = lib.mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable [cosmic-edit](${pkgs.cosmic-edit.meta.homepage}).
      '';
    };
    package = lib.mkOption {
      type = types.package;
      default = pkgs.cosmic-edit.override (
        lib.optionalAttrs (udevApi != null) {
          inherit libinput;
        }
      );
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
