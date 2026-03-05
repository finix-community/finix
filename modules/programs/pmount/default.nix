{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.pmount;

  mkSetuidWrapper = package: command: {
    setuid = true;
    owner = "root";
    group = "root";
    source = lib.getExe' package command;
  };
in
{
  options.programs.pmount = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [pmount](${cfg.package.meta.homepage}).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.pmount;
      defaultText = lib.literalExpression "pkgs.pmount";
      description = ''
        The package to use for `pmount`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    security.wrappers = {
      pmount = mkSetuidWrapper cfg.package "pmount";
      pumount = mkSetuidWrapper cfg.package "pumount";
    };

    finit.tmpfiles.rules = [
      "d /media - root root - -"
    ];
  };
}
