{
  config,
  lib,
  ...
}:
let
  cfg = config.programs.nvidia-settings;
in
{
  options.programs.nvidia-settings = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [nvidia-settings](https://github.com/NVIDIA/nvidia-settings).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = config.hardware.nvidia.package.settings;
      defaultText = lib.literalExpression "config.hardware.nvidia.package.settings";
      description = ''
        The package to use for `nvidia-settings`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.hardware.nvidia.enable or false;
        message = "The programs.nvidia-settings module requires the hardware.nvidia module. Please set hardware.nvidia.enable to true.";
      }
    ];

    environment.systemPackages = [ cfg.package ];
  };
}
