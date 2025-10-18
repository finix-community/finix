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
in
{
  options.programs.niri = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [niri](${pkgs.niri.meta.homepage}).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.niri;
      defaultText = lib.literalExpression "pkgs.niri";
      description = ''
        The package to use for `niri`.
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
