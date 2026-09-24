{
  lib,
  pkgs,
  config,
  modules,
  ...
}:
let
  inherit (lib) types;
  cfg = config.programs.cosmic-osd;
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
  imports = [ modules.pipewire ];

  options.programs.cosmic-osd = {
    enable = lib.mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable [cosmic-osd](${pkgs.cosmic-osd.meta.homepage}).
      '';
    };
    package = lib.mkOption {
      type = types.package;
      default = pkgs.cosmic-osd.override (
        lib.optionalAttrs (udevApi != null) {
          udev = udevApi;
          inherit libinput;
          pipewire = config.programs.pipewire.package;
        }
      );
      defaultText = lib.literalExpression "pkgs.cosmic-osd";
      description = ''
        The package to use for `cosmic-osd`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
