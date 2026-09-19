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
      description = "Whether to enable the Facter Debug module";
      default = false;
    };

    noFacter = lib.mkOption {
      type = lib.types.unspecified;
      description = "A version of the system closure with facter disabled";
    };

    nvd = lib.mkOption {
      type = lib.types.package;
      description = ''
        A shell application which will produce an nvd diff of the system closure with and without facter enabled.
      '';
    };

    nix-diff = lib.mkOption {
      type = lib.types.package;
      description = ''
        A shell application which will produce a nix-diff of the system closure with and without facter enabled.
      '';
    };
  };

  config = lib.mkIf (config.hardware.facter.enable && cfg.enable) {
    hardware.facter.debug = {
      noFacter = extendModules {
        modules = [
          {
            # we 'disable' facter by overriding the report and setting it to empty with one caveat: hostPlatform
            config.hardware.facter.report = lib.mkForce {
              system = config.nixpkgs.pkgs.stdenv.hostPlatform;
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

      nix-diff = pkgs.writeShellApplication {
        name = "facter-nix-diff";
        runtimeInputs = [
          config.services.nix-daemon.package
          pkgs.nix-diff
        ];
        text = ''
          nix-diff \
            ${config.hardware.facter.debug.noFacter.config.system.build.toplevel} \
            ${config.system.build.toplevel} \
            "$@"
        '';
      };
    };

    environment.systemPackages = [
      cfg.nvd
      cfg.nix-diff
    ];
  };
}
