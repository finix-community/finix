{ config, lib, ... }:

let
  inherit (lib)
    mkBefore
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
    hardware.console.keyMap = "us";
    boot.init.pid1.env.NO_COLOR = "1";
    synit.logging.logToFileSystem = false;
    virtualisation.qemu = {
      extraArgs = lib.optional (!cfg.graphics.enable) "-nographic";
      nics.eth0.args = mkBefore [
        "user"
        "model=virtio-net-pci"
      ];
    };
  };
}
