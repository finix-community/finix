{
  lib,
  pkgs,
  config,
  modules,
  ...
}:
let
  inherit (lib) types;
  cfg = config.programs.cosmic-settings;
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
  imports = [
    modules.pipewire
  ];

  options = {
    programs.cosmic-settings = {
      enable = lib.mkEnableOption "COSMIC settings";
      package = lib.mkOption {
        type = types.package;
        default = pkgs.cosmic-settings.override {
          udev = udevApi;
          inherit libinput;
          pipewire = config.programs.pipewire.package;
        };
        defaultText = lib.literalExpression "pkgs.cosmic-settings";
        description = ''
          The package to use for `cosmic-settings`.
        '';
      };
      daemon.package = lib.mkOption {
        type = types.package;
        default = pkgs.cosmic-settings-daemon.override {
          udev = udevApi;
          inherit libinput;
          pipewire = config.programs.pipewire.package;
        };
        defaultText = lib.literalExpression "pkgs.cosmic-settings-daemon";
        description = ''
          The package to use for `cosmic-settings-daemon`.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
      cfg.daemon.package
    ];
  };
}
