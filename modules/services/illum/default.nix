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
  };

  config = lib.mkIf cfg.enable {
    finit.services.illum = {
      description = "backlight adjustment service";
      command = "${pkgs.illum}/bin/illum-d";
      log = true;
    };
  };
}
