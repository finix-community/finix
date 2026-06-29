{
  config,
  lib,
  ...
}:
let
  cfg = config.boot.loader.external;
  efi = config.boot.loader.efi;
in
{
  options.boot.loader.efi = {
    canTouchEfiVariables = lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = "Whether the installation process is allowed to modify EFI boot variables.";
    };

    efiSysMountPoint = lib.mkOption {
      default = "/boot";
      type = lib.types.str;
      description = "Where the EFI System Partition is mounted.";
    };
  };

  options.boot.loader.external = {
    enable = lib.mkEnableOption "an external bootloader install hook";

    installHook = lib.mkOption {
      type = lib.types.path;
      description = ''
        A program that installs the bootloader. Called with one argument:
        the path to the system toplevel.

        This is the same contract as {option}`providers.bootloader.installHook`.
        Setting this option wires the hook into the finix provider automatically.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.installHook != null;
        message = "boot.loader.external.enable = true but installHook is not set.";
      }
    ];

    providers.bootloader.installHook = cfg.installHook;

    boot.supportedFilesystems.efivarfs.enable =
      lib.mkIf efi.canTouchEfiVariables true;

    fileSystems."/sys/firmware/efi/efivars" = lib.mkIf efi.canTouchEfiVariables {
      device = "efivarfs";
      fsType = "efivarfs";
      options = [
        "defaults"
        "nofail"
      ];
    };
  };
}
