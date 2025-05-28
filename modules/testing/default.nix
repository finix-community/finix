{ config, lib, ... }:

let
  inherit (lib) mkEnableOption mkOption types;
  cfg = config.testing;
in
{
  options = {
    testing.enable = mkEnableOption "test instrumentation";

    testing.driver = mkOption {
      type = types.enum [ "tcl" ];
      description = "Test driver.";
    };

    testing.graphics.enable = mkEnableOption "graphic devices";
  };

  config = {
    virtualisation.qemu.extraArgs = lib.optional (!cfg.graphics.enable) "-nographic";
  };
}
