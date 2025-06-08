{ config, lib, ... }:

let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.testing;
in
{
  options = {
    testing.enable = mkEnableOption "test instrumentation";

    testing.enableRootDisk = mkEnableOption "use a root file-system on a disk image otherwise use tmpfs";

    testing.driver = mkOption {
      type = types.enum [ "tcl" ];
      description = "Test driver.";
    };

    testing.graphics.enable = mkEnableOption "graphic devices";
  };

  config = mkIf cfg.enable {
    synit.logging.logToFileSystem = false;
    virtualisation.qemu.extraArgs = lib.optional (!cfg.graphics.enable) "-nographic";

  };
}
