{
  lib,
  pkgs,
  config,
  extendModules,
  ...
}:
let
  cfg = config.hardware.facter.debug;
in
{
  options.hardware.facter.debug = {
    enable = lib.mkOption {
      type = lib.types.bool;
      description = "Whether to enable the Facter Debug module. This increases evaluation time so you might not want to leave it enabled.";
      default = false;
    };

    noFacter = lib.mkOption {
      type = lib.types.unspecified;
      internal = true;
      visible = false;
      description = "A version of the system closure with facter disabled";
    };

    nvd = lib.mkOption {
      type = lib.types.package;
      description = ''
        A shell application which will produce an nvd diff of the system closure with and without facter enabled.
      '';
    };
  };

  config = lib.mkIf (config.hardware.facter.enable && cfg.enable) {
    hardware.facter.debug = {
      noFacter = extendModules {
        modules = [
          {
            config.hardware.facter.debug.enable = lib.mkForce false;
            config.hardware.facter.report = lib.mkForce {
              system = pkgs.stdenv.hostPlatform;
            };
          }
        ];
      };

      nvd = pkgs.writeShellApplication {
        name = "facter-nvd-diff";
        runtimeInputs = [
          config.services.nix-daemon.package
          pkgs.nvd
        ];
        text = ''
          nvd diff \
            ${config.hardware.facter.debug.noFacter.config.system.build.toplevel} \
            ${config.system.build.toplevel} \
            "$@"
        '';
      };
    };
  };
}
