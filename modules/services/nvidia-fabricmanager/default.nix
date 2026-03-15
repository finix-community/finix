{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.nvidia-fabricmanager;

  format = pkgs.formats.keyValue { };
  configFile = format.generate "fabricmanager.conf" cfg.datacenter.settings;
in
{
  options.services.nvidia-fabricmanager = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [nvidia-fabricmanager](https://docs.nvidia.com/datacenter/tesla/fabric-manager-user-guide/index.html) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = config.hardware.nvidia.package.fabricmanager;
      defaultText = lib.literalExpression "config.hardware.nvidia.package.fabricmanager";
      description = ''
        The package to use for `nvidia-fabricmanager`.
      '';
    };

    settings = lib.mkOption {
      type = format.type;
      default = { };
      description = ''
        `tlp` configuration. See [upstream documentation](https://docs.nvidia.com/datacenter/tesla/fabric-manager-user-guide/index.html#fabric-manager-config-options)
        for additional details.
      '';
    };

    extraArgs = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = ''
        Additional arguments to pass to `nvidia-fabricmanager`. See [upstream documentation](https://docs.nvidia.com/datacenter/tesla/fabric-manager-user-guide/index.html#fabric-manager-startup-options)
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          config.hardware.nvidia.enable or false && config.hardware.nvidia.datacenter.enable or false;
        message = "The services.nvidia-fabricmanager module requires the hardware.nvidia module. Please set hardware.nvidia.enable and hardware.nvidia.datacenter.enable to true.";
      }
    ];

    services.nvidia-fabricmanager.settings = {
      DAEMONIZE = 1; # TODO: shouldn't we run this as daemon then not fork??
      DATABASE_PATH = "${cfg.package}/share/nvidia-fabricmanager/nvidia/nvswitch";
      LOG_USE_SYSLOG = 1;
      STATE_FILE_NAME = "/var/tmp/fabricmanager.state";
      TOPOLOGY_FILE_PATH = "${cfg.package}/share/nvidia-fabricmanager/nvidia/nvswitch";
    };

    services.nvidia-fabricmanager.extraArgs = [
      "--config"
      configFile
    ];

    environment.systemPackages = [ cfg.package ];

    finit.services.nvidia-fabricmanager = {
      description = "start NVIDIA NVLink management";
      command = "${lib.getExe cfg.package} " + lib.escapeShellArgs cfg.extraArgs;
      type = "forking";
      conditions = [ "net/route/default" ];
      restart = -1;
    };
  };
}
