{
  modules,
  lib,
  config,
  ...
}:
{
  imports = [ modules.bluetooth ];

  options.hardware.facter.detected.bluetooth.enable = lib.mkOption {
    description = "Whether to enable the Facter bluetooth module";
    default = builtins.length (config.hardware.facter.report.hardware.bluetooth or [ ]) > 0;
    defaultText = "hardware dependent";
  };

  config.services.bluetooth.enable = lib.mkIf config.hardware.facter.detected.bluetooth.enable (
    lib.mkDefault true
  );
}
