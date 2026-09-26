{
  lib,
  pkgs,
  config,
  modules,
  ...
}:
let
  cfg = config.programs.cosmic-session;
in
{
  imports = [
    modules.cosmic-settings
    modules.cosmic-applets
    modules.cosmic-comp
  ];

  options.programs.cosmic-session = {
    enable = lib.mkEnableOption "COSMIC session";
    package = lib.mkPackageOption pkgs "cosmic-session" { };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
      # Necessary dependencies, `cosmic-session` crashes without them
      pkgs.cosmic-notifications
      pkgs.cosmic-panel
    ];

    programs = {
      cosmic-settings.enable = true;
      cosmic-comp.enable = true;
      cosmic-applets.enable = true;
    };
  };
}
