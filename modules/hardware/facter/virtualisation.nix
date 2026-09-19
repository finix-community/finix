{
  lib,
  config,
  options,
  ...
}:
let
  inherit (config.hardware.facter) report;
in
{
  options.hardware.facter.detected.virtualisation = {
    # TODO: idk what to do with this yet
    qemu.enable = lib.mkOption {
      type = lib.types.bool;
      default = builtins.elem (report.virtualisation or null) [
        "qemu"
        "kvm"
        "bochs"
      ];
      defaultText = "environment dependent";
      description = "Whether to enable the Facter Virtualisation Qemu module.";
    };

    none.enable = lib.mkOption {
      type = lib.types.bool;
      default = report.virtualisation or null == "none";
      defaultText = "environment dependent";
      description = "Whether to enable the Facter Virtualisation None module.";
    };
  };

  config = lib.mkIf config.hardware.facter.enable {
    # KVM support
    boot.kernelModules =
      let
        hasCPUFeature =
          feature:
          lib.any (
            {
              features ? [ ],
              ...
            }:
            lib.elem feature features
          ) (report.hardware.cpu or [ ]);
      in
      lib.optional (hasCPUFeature "vmx") "kvm-intel" ++ lib.optional (hasCPUFeature "svm") "kvm-amd";
  };
}
