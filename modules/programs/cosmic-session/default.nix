{
  lib,
  pkgs,
  config,
  modules,
  ...
}:
let
  cfg = config.programs.cosmic-session;
  inherit (lib) types;
in
{
  imports = [
    modules.cosmic-settings
    modules.cosmic-applets
    modules.cosmic-comp
  ];

  options.programs.cosmic-session = {
    enable = lib.mkOption {
      type = types.bool;
      default = false;
      description = "Enable COSMIC session.";
    };
    package = lib.mkOption {
      type = types.package;
      default = pkgs.cosmic-session;
      defaultText = lib.literalExpression "pkgs.cosmic-session";
      description = ''
        The package to use for `cosmic-session`.
      '';
    };
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
