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
    none.enable = lib.mkOption {
      type = lib.types.bool;
      default = report.virtualisation or null == "none";
      internal = true;
      visible = false;
      defaultText = "Enabled based on hardware report.";
      description = "Whether to enable the Facter Virtualisation None module.";
    };
  };

  config = lib.mkIf config.hardware.facter.enable {
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
