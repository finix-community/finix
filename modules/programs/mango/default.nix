{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.mango;

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
  imports = [
    (lib.mkRenamedOptionModule [ "programs" "mangowc" ] [ "programs" "mango" ])
  ];

  options.programs.mango = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [mango](${pkgs.mango.meta.homepage}).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.mango.override {
        inherit libinput;

        wlroots_0_19 = pkgs.wlroots_0_19.override { inherit libinput; };
      };
      defaultText = lib.literalExpression "pkgs.mango";
      description = ''
        The package to use for `mango`.
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
