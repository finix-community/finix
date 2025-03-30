{ config, pkgs, lib, ... }:
let
  cfg = config.services.illum;
in
{
  options.services.illum = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
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
