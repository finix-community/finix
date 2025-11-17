{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.illum;
in
{
  options.services.illum = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [illum](${pkgs.illum.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.illum.override (
        lib.optionalAttrs config.services.mdevd.enable {
          udev = pkgs.libudev-zero;
        }
      );
      defaultText = lib.literalExpression "pkgs.illum";
      description = ''
        The package to use for `illum`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    finit.services.illum = {
      description = "backlight adjustment service";
      command = lib.getExe cfg.package;
      conditions = [ "service/syslogd/ready" ];
      log = true;
      nohup = true;
    };
  };
}
