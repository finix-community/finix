{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.umbriel;

  sessionFile = pkgs.writeTextDir "share/wayland-sessions/umbriel.desktop" ''
    [Desktop Entry]
    Comment=Umbrel, a Wayland compositor built on wlroots and SceneFX
    DesktopNames=umbriel
    Exec=${lib.getExe' pkgs.dbus "dbus-run-session"} -- ${lib.getExe' cfg.package "start-umbriel"}
    Name=Umbriel
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
  options.programs.umbriel = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [umbriel](${pkgs.umbriel.meta.homepage}).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.umbriel.override (
        o:
        let
          wlrootsAttrs = lib.head (lib.filter (lib.hasPrefix "wlroots") (lib.attrNames o));
        in
        {
          inherit libinput;
          ${wlrootsAttrs} = o.${wlrootsAttrs}.override { inherit libinput; };
        }
      );
      defaultText = lib.literalExpression "pkgs.umbriel";
      description = ''
        The package to use for `umbriel`.
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
