{
  modules,
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.vxwm;

  sessionFile = pkgs.writeTextDir "share/xsessions/vxwm.desktop" ''
    [Desktop Entry]
    Name=vxwm
    Comment=Versatile X Window Manager
    Exec=${pkgs.dbus}/bin/dbus-run-session -- ${cfg.package}/bin/vxwm
    TryExec=${cfg.package}/bin/vxwm
    Type=Application
    DesktopNames=vxwm
  '';
in
{
  imports = [ modules.xorg ];

  options.programs.vxwm = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable [vxwm](${pkgs.vxwm.meta.homepage}).";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.vxwm;
      defaultText = lib.literalExpression "pkgs.vxwm";
      description = "The package to use for `vxwm`.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.xorg.enable = true;

    environment.systemPackages = [
      cfg.package
      (lib.hiPrio sessionFile)
    ];
  };
}
