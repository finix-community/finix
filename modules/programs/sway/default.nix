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

  sway-unwrapped = pkgs.sway-unwrapped.override (
    o:
    let
      wlrootsAttr = lib.head (lib.filter (lib.hasPrefix "wlroots") (lib.attrNames o));
    in
    {
      inherit libinput;
      ${wlrootsAttr} = o.${wlrootsAttr}.override { inherit libinput; };

      # since we're recompiling go ahead and disable systemd
      systemdSupport = udevApi == null;
    }
  );
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
