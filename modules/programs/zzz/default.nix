{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.zzz;
in
{
  imports = [
    ./providers.resume-and-suspend.nix
  ];

  options.programs.zzz = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [zzz](${cfg.package.meta.homepage}).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.zzz;
      defaultText = lib.literalExpression "pkgs.zzz";
      description = ''
        The package to use for `zzz`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    # this module supplies an implementation for `providers.resumeAndSuspend`
    providers.resumeAndSuspend.backend = "zzz";
  };
}
