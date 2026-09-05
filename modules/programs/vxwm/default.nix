{
  modules,
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.vxwm;

  sessionScript = pkgs.writeShellScript "vxwm-session" ''
    ${lib.concatStringsSep "\n" cfg.autostart}
    exec ${cfg.package}/bin/vxwm
  '';

  sessionFile = pkgs.writeTextDir "share/xsessions/vxwm.desktop" ''
    [Desktop Entry]
    Name=vxwm
    Comment=Versatile X Window Manager
    Exec=${pkgs.dbus}/bin/dbus-run-session -- ${sessionScript}
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

    autostart = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      example = lib.literalExpression ''[ "pipewire &" "picom &" ]'';
      description = "Commands to run before starting vxwm. Each string is a shell command.";
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
