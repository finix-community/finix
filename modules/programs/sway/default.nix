{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.sway;

  sessionFile = pkgs.writeTextDir "share/wayland-sessions/sway.desktop" ''
    [Desktop Entry]
    Name=Sway
    Comment=An i3-compatible Wayland compositor
    Exec=${pkgs.dbus}/bin/dbus-run-session -- ${lib.getExe cfg.package}
    Type=Application
    DesktopNames=sway;wlroots
  '';

  # libudev-zero is a hard requirement when running mdevd
  libinput = pkgs.libinput.override (
    lib.optionalAttrs config.services.mdevd.enable {
      udev = pkgs.libudev-zero;
      wacomSupport = false;
    }
  );

  wlroots_0_19 = pkgs.wlroots_0_19.override {
    inherit libinput;

    # xwayland appears to cause issues with mdevd - and not required in this context, so no harm in removing
    enableXWayland = !config.services.mdevd.enable;
  };

  sway-unwrapped = pkgs.sway-unwrapped.override {
    inherit libinput wlroots_0_19;

    # since we're recompiling go ahead and disable systemd
    systemdSupport = !config.services.mdevd.enable;
  };
in
{
  options.programs.sway = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [sway](${pkgs.sway.meta.homepage}).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.sway.override {
        inherit sway-unwrapped;
      };
      defaultText = lib.literalExpression "pkgs.sway";
      description = ''
        The package to use for `sway`.
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
