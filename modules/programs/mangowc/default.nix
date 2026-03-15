{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.mangowc;

  sessionFile = pkgs.writeTextDir "share/wayland-sessions/mango.desktop" ''
    [Desktop Entry]
    Encoding=UTF-8
    Name=Mango
    DesktopNames=mango;wlroots
    Comment=mango WM
    Exec=${pkgs.dbus}/bin/dbus-run-session -- ${lib.getExe cfg.package}
    Icon=mango
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
  options.programs.mangowc = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [mangowc](${pkgs.mangowc.meta.homepage}).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.mangowc.override {
        inherit libinput;

        wlroots_0_19 = pkgs.wlroots_0_19.override { inherit libinput; };
      };
      defaultText = lib.literalExpression "pkgs.mangowc";
      description = ''
        The package to use for `mangowc`.
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
