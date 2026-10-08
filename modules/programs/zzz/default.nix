{
  modules,
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
    modules.sessiond-power
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

    services.sessiond.settings =
      lib.mkIf
        (
          config.services.sessiond.enable
          && lib.versionOlder (lib.getVersion config.services.sessiond.package) "0.3.0"
        )
        {
          power = {
            hibernate = lib.mkDefault [
              (lib.getExe config.programs.zzz.package)
              "-Z"
            ];
            suspend = [
              (lib.getExe config.programs.zzz.package)
              "-z"
            ];
          };
        };

    services.sessiond-power.settings = lib.mkIf config.services.sessiond-power.enable {
      hibernate = lib.mkDefault [
        (lib.getExe config.programs.zzz.package)
        "-Z"
      ];
      suspend = [
        (lib.getExe config.programs.zzz.package)
        "-z"
      ];
      hybrid-sleep = [
        (lib.getExe config.programs.zzz.package)
        "-H"
      ];
    };

    # this module supplies an implementation for `providers.resumeAndSuspend`
    providers.resumeAndSuspend.backend = "zzz";
  };
}
