{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.nvidia-powerd;
in
{
  options.services.nvidia-powerd = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable `nvidia-powerd` as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = config.hardware.nvidia.package;
      defaultText = lib.literalExpression "config.hardware.nvidia.package";
      description = ''
        The package to use for `nvidia-powerd`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.hardware.nvidia.enable or false;
        message = "The services.nvidia-persistenced module requires the hardware.nvidia module. Please set hardware.nvidia.enable to true.";
      }
      {
        assertion = lib.versionAtLeast cfg.package.version "510.39.01";
        message = "NVIDIA's Dynamic Boost feature only exists on versions >= 510.39.01";
      }
    ];

    services.dbus.packages = cfg.package.bin;

    finit.services.nvidia-powerd = {
      description = "NVIDIA Dynamic Boost";
      command = "${cfg.package.bin}/bin/nvidia-powerd";
      path = [ pkgs.util-linux ]; # nvidia-powerd wants lscpu
      restart = -1;
    };
  };
}
