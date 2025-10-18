{ config, pkgs, lib, ... }:
let
  cfg = config.programs.bash;
in
{
  options.programs.bash = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [bash](${pkgs.bash.meta.homepage}).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.bashInteractive;
      defaultText = lib.literalExpression "pkgs.bashInteractive";
      description = ''
        The package to use for `bash`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    environment.shells = [
      "/run/current-system/sw/bin/bash"
      (lib.getExe cfg.package)
    ];
  };
}
