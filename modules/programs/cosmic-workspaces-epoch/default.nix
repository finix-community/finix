{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.programs.cosmic-workspaces-epoch;
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
  options.programs.cosmic-workspaces-epoch = {
    enable = lib.mkEnableOption "COSMIC workspaces epoch";
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.cosmic-workspaces-epoch.override {
        udev = udevApi;
        inherit libinput;
      };
      defaultText = lib.literalExpression "pkgs.cosmic-workspaces-epoch";
      description = ''
        The package to use for `cosmic-workspaces-epoch`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
