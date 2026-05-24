{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.niri;

  sessionFile = pkgs.writeTextDir "share/wayland-sessions/niri.desktop" ''
    [Desktop Entry]
    Comment=A scrollable-tiling Wayland compositor
    DesktopNames=niri
    Exec=${pkgs.dbus}/bin/dbus-run-session -- ${lib.getExe cfg.package} --session
    Name=Niri
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

  overrideAttrs = lib.optionalAttrs (udevApi != null) {
    eudev = udevApi;

    libinput = pkgs.libinput.override {
      udev = udevApi;
      wacomSupport = false;
    };

    # since we're recompiling go ahead and disable systemd
    withSystemd = false;
  };
in
{
  options.programs.niri = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [niri](${pkgs.niri.meta.homepage}).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.niri.override overrideAttrs;
      defaultText = lib.literalExpression "pkgs.niri";
      description = ''
        The package to use for `niri`.
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
