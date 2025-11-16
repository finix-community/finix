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
    Exec=${pkgs.dbus}/bin/dbus-run-session -- ${lib.getExe cfg.package}
    Icon=labwc
    Name=labwc
    Type=Application
  '';

  # libudev-zero is a hard requirement when running mdevd
  libinput = pkgs.libinput.override (
    lib.optionalAttrs config.services.mdevd.enable {
      udev = pkgs.libudev-zero;
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

        wlroots_0_19 = pkgs.wlroots_0_19.override { inherit libinput; };
      };
      defaultText = lib.literalExpression "pkgs.labwc";
      description = ''
        The package to use for `labwc`.
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
