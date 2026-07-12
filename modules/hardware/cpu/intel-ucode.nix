{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.cpu.intel;
in
{
  options.hardware.cpu.intel = {
    updateMicrocode = lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = ''
        Update the CPU microcode for Intel processors.
      '';
    };

    microcodePackage = lib.mkOption {
      default = pkgs.microcode-intel;
      type = lib.types.package;
    };
  };

  config = lib.mkIf cfg.updateMicrocode {
    boot.initrd.prepend = lib.mkOrder 1 [ "${cfg.microcodePackage}/intel-ucode.img" ];
  };
}
