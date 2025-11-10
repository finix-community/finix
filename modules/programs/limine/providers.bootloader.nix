{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.limine;

  limineInstallConfig = pkgs.writeText "limine-install.json" (
    builtins.toJSON {
      inherit (cfg)
        additionalFiles
        biosDevice
        biosSupport
        efiSupport
        enrollConfig
        extraEntries
        force
        partitionIndex
        settings
        validateChecksums
        ;

      nixPath = config.services.nix-daemon.package;
      efiBootMgrPath = pkgs.efibootmgr;
      liminePath = cfg.package;
      efiMountPoint = config.boot.loader.efi.efiSysMountPoint;
      fileSystems = config.fileSystems;
      canTouchEfiVariables = config.boot.loader.efi.canTouchEfiVariables;
      efiRemovable = cfg.efiInstallAsRemovable;
      maxGenerations = if cfg.maxGenerations == null then 0 else cfg.maxGenerations;
      hostArchitecture = pkgs.stdenv.hostPlatform.parsed.cpu;
    }
  );
in
{
  options.providers.bootloader = {
    backend = lib.mkOption {
      type = lib.types.enum [ "limine" ];
    };
  };

  config = lib.mkIf (config.providers.bootloader.backend == "limine") {
    providers.bootloader.installHook = pkgs.replaceVarsWith {
      src = ./limine-install.py;
      isExecutable = true;
      replacements = {
        python3 = pkgs.python3.withPackages (python-packages: [ python-packages.psutil ]);
        configPath = limineInstallConfig;
      };
    };
  };
}
