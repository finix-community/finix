{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.hyprland;

  sessionFile = pkgs.writeTextDir "share/wayland-sessions/hyprland.desktop" ''
    [Desktop Entry]
    Name=Hyprland
    Comment=An intelligent dynamic tiling Wayland compositor
    Exec=${pkgs.dbus}/bin/dbus-run-session -- ${lib.getExe cfg.package}
    Type=Application
    DesktopNames=Hyprland
    Keywords=tiling;wayland;compositor;
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

  aquamarine = pkgs.aquamarine.override (
    lib.optionalAttrs (udevApi != null) {
      inherit libinput;

      udev = udevApi;
    }
  );
in
{
  options.programs.hyprland = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [hyprland](${pkgs.hyprland.meta.homepage}).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.hyprland.override {
        inherit aquamarine libinput;

        # since we're recompiling go ahead and disable systemd
        withSystemd = udevApi == null;
      };
      defaultText = lib.literalExpression "pkgs.hyprland";
      description = ''
        The package to use for `hyprland`.
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
