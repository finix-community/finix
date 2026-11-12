{
  modules,
  lib,
  config,
  ...
}:
{
  options.hardware.facter.detected.bluetooth.enable = lib.mkOption {
    description = "Whether to enable the Facter bluetooth module";
    default = builtins.length (config.hardware.facter.report.hardware.bluetooth or [ ]) > 0;
    internal = true;
    visible = false;
    defaultText = "Enabled based on hardware report.";
  };

  config.services.bluetooth.enable = lib.mkIf config.hardware.facter.detected.bluetooth.enable true;
}
