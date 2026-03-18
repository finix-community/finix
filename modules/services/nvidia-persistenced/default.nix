{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.nvidia-persistenced;

  runtimeDir = "/var/run/nvidia-persistenced";
in
{
  options.services.nvidia-persistenced = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [nvidia-persistenced](https://docs.nvidia.com/deploy/driver-persistence/persistence-daemon.html) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = config.hardware.nvidia.package.persistenced;
      defaultText = lib.literalExpression "config.hardware.nvidia.package.persistenced";
      description = ''
        The package to use for `nvidia-persistenced`.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.
      '';
    };

    extraArgs = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = ''
        Additional arguments to pass to `nvidia-persistenced`. See {manpage}`nvidia-persistenced(1)`
        for additional details.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "nvidia-persistenced";
      description = ''
        User account under which `nvidia-persistenced` runs.

        ::: {.note}
        If left as the default value this user will automatically be created
        on system activation, otherwise you are responsible for
        ensuring the user exists before the `nvidia-persistenced` service starts.
        :::
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "nvidia-persistenced";
      description = ''
        Group account under which `nvidia-persistenced` runs.

        ::: {.note}
        If left as the default value this group will automatically be created
        on system activation, otherwise you are responsible for
        ensuring the group exists before the `nvidia-persistenced` service starts.
        :::
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.hardware.nvidia.enable or false;
        message = "The services.nvidia-persistenced module requires the hardware.nvidia module. Please set hardware.nvidia.enable to true.";
      }
    ];

    services.nvidia-persistenced.extraArgs = lib.optionals cfg.debug [ "--verbose" ];

    environment.systemPackages = [ cfg.package ];

    finit.services.nvidia-persistenced = {
      inherit (cfg) user group;

      description = "NVIDIA persistence daemon";
      command = "${lib.getExe cfg.package} " + lib.escapeShellArgs cfg.extraArgs;
      type = "forking";
      pid = "${runtimeDir}/nvidia-persistenced.pid";
      post = pkgs.writeShellScript "nvidia-persistenced-post.sh" "${lib.getExe pkgs.findutils} ${runtimeDir} -mindepth 1 -delete";
      restart = -1;
    };

    finit.tmpfiles.rules = [
      "d ${runtimeDir} 0750 ${cfg.user} ${cfg.group}"
    ];

    users.users = lib.optionalAttrs (cfg.user == "nvidia-persistenced") {
      nvidia-persistenced = {
        inherit (cfg) group;
      };
    };

    users.groups = lib.optionalAttrs (cfg.group == "nvidia-persistenced") {
      nvidia-persistenced = { };
    };
  };
}
