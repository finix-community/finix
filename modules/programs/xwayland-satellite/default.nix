{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.xwayland-satellite;
in
{
  options.programs.xwayland-satellite = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [xwayland-satellite](${pkgs.xwayland-satellite.meta.homepage}).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.xwayland-satellite;
      defaultText = lib.literalExpression "pkgs.xwayland-satellite";
      description = ''
        The package to use for `xwayland-satellite`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    finit.tmpfiles.rules = [
      "D! /tmp/.X11-unix  1777 root root"
      "D! /tmp/.ICE-unix  1777 root root"
      "D! /tmp/.XIM-unix  1777 root root"
      "D! /tmp/.font-unix 1777 root root"

      "z  /tmp/.X11-unix"
      "z  /tmp/.ICE-unix"
      "z  /tmp/.XIM-unix"
      "z  /tmp/.font-unix"

      "r! /tmp/.X[0-9]*-lock"
    ];
  };
}
