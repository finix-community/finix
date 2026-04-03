{
  config,
  pkgs,
  lib,
  ...
}:
{
  options.xdg.icons.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf config.xdg.icons.enable {
    environment.pathsToLink = [
      "/share/icons"
      "/share/pixmaps"
    ];

    environment.systemPackages = [ pkgs.hicolor-icon-theme ];
  };
}
