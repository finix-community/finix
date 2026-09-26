{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) types;
  cfg = config.programs.cosmic-comp;
  udevApi =
    if config.services.gardendevd.enable then
      pkgs.libudev-garden
    else if config.services.mdevd.enable || config.services.keventd.enable then
      pkgs.libudev-zero
    else
      null;
  sessionFile = pkgs.writeTextDir "share/wayland-sessions/cosmic.desktop" ''
    [Desktop Entry]
    Name=COSMIC
    Comment=This session logs you into the COSMIC desktop
    Comment[sv]=Denna session loggar in dig till skrivbordsmiljön COSMIC
    Exec=${pkgs.dbus}/bin/dbus-run-session -- ${lib.getExe cfg.package}
    Type=Application
    DesktopNames=COSMIC
  '';
in
{
  options = {
    programs.cosmic-comp = {
      enable = lib.mkEnableOption "COSMIC compositor";
      package = lib.mkOption {
        type = types.package;
        default = pkgs.cosmic-comp.override {
          useSystemd = false;
          udev = udevApi;
          libinput = pkgs.libinput.override (
            lib.optionalAttrs (udevApi != null) {
              udev = udevApi;
              wacomSupport = false;
            }
          );
        };
        defaultText = lib.literalExpression "pkgs.cosmic-comp";
        description = ''
          The package to use for `cosmic-comp`.
        '';
      };
      xwayland.enable = lib.mkEnableOption "Xwayland support for the COSMIC compositor" // {
        default = true;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
      # cosmic-comp doesn't install a session file by itself so `lib.hiPrio` is unnecessary
      # and by setting it to `lib.lowPrio` we let `cosmic-session` install its own session file
      # which depending on availability of `DBUS_SESSION_BUS_ADDRESS` runs `dbus-run-session`
      (lib.lowPrio sessionFile)
    ]
    ++ lib.optionals cfg.xwayland.enable [ pkgs.xwayland ];
  };
}
