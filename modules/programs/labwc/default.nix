{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.labwc;

  sessionFile = pkgs.writeTextDir "share/wayland-sessions/labwc.desktop" ''
    [Desktop Entry]
    Comment=A wayland stacking compositor
    DesktopNames=labwc;wlroots
    Exec=${pkgs.dbus}/bin/dbus-run-session -- ${lib.getExe cfg.package} ${lib.escapeShellArgs cfg.extraArgs}
    Icon=labwc
    Name=labwc
    Type=Application
  '';

  # gardendevd needs libudev-garden; mdevd/keventd need libudev-zero
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
  options.programs.labwc = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [labwc](${pkgs.labwc.meta.homepage}).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.labwc.override {
        inherit libinput;

        wlroots_0_20 = pkgs.wlroots_0_20.override { inherit libinput; };
        enableSystemd = false;
      };
      defaultText = lib.literalExpression "pkgs.labwc";
      description = ''
        The package to use for `labwc`.
      '';
    };

    extraArgs = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = ''
        Additional arguments to pass to `labwc`. See {manpage}`labwc(1)`
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package

      # override wayland session with one that includes absolute paths + dbus-run-session invocation
      (lib.hiPrio sessionFile)
    ];
  };
}
