{ config, pkgs, lib, ... }:
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

  # libudev-zero is a hard requirement when running mdevd
  libinput = pkgs.libinput.override (lib.optionalAttrs config.services.mdevd.enable {
    udev = pkgs.libudev-zero;
    wacomSupport = false;
  });
in
{
  options.programs.niri = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.niri.override {
        inherit libinput;

        # since we're recompiling anyways we may as well disable systemd since it isn't used
        withSystemd = !config.services.mdevd.enable;
      };
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
