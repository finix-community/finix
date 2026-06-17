{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hardware.cpu.amd;
in
{
  options.hardware.cpu.amd = {
    updateMicrocode = lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = ''
        Update the CPU microcode for AMD processors.
      '';
    };

    microcodePackage = lib.mkOption {
      default = pkgs.microcode-amd;
      type = lib.types.package;
    };
  };

  config = lib.mkIf cfg.updateMicrocode {
    boot.initrd.prepend = lib.mkOrder 1 [ "${cfg.microcodePackage}/amd-ucode.img" ];
  };
}
