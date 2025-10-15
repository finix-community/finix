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

  # libudev-zero is a hard requirement when running mdevd
  libinput = pkgs.libinput.override (
    lib.optionalAttrs config.services.mdevd.enable {
      udev = pkgs.libudev-zero;
      wacomSupport = false;
    }
  );

  aquamarine = pkgs.aquamarine.override (
    lib.optionalAttrs config.services.mdevd.enable {
      inherit libinput;

      udev = pkgs.libudev-zero;
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
        withSystemd = !config.services.mdevd.enable;
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
