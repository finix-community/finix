{ config, pkgs, lib, ... }:
let
  cfg = config.programs.fish;
in
{
  options.programs.fish = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [fish](${pkgs.fish.meta.homepage}).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.fish;
      defaultText = lib.literalExpression "pkgs.fish";
      description = ''
        The package to use for `fish`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment = {
      pathsToLink = [ "/share/fish" ];
      systemPackages = [ cfg.package ];
      shells = [
        "/run/current-system/sw/bin/fish"
        (lib.getExe cfg.package)
      ];
    };
  };
}
