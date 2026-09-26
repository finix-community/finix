{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.boot.loader.script;
in
{
  options.providers.bootloader = {
    backend = lib.mkOption {
      type = lib.types.enum [
        "none"
        "script"
      ];
      default = "none";
      description = ''
        The selected module which should implement functionality for the {option}`providers.bootloader` contract.
      '';
    };

    installHook = lib.mkOption {
      type = lib.types.path;
      default = pkgs.writeShellScript "no-bootloader" ''
        echo 'Warning: do not know how to make this configuration bootable; please enable a boot loader.' 1>&2
      '';
      defaultText = lib.literalExpression ''
        pkgs.writeShellScript "no-bootloader" '''
          echo 'Warning: do not know how to make this configuration bootable; please enable a boot loader.' 1>&2
        '''
      '';
      description = ''
        The full path to a program of your choosing which performs the bootloader installation process.

        The program will be called with an argument pointing to the output of the system's toplevel.
      '';
    };
  };

  options.boot.loader.script = {
    enable = lib.mkEnableOption "an externally-provided bootloader install hook";

    installHook = lib.mkOption {
      type = lib.types.path;
      description = ''
        A program that installs the bootloader. Called with one argument: the path to the system toplevel.

        This is the same contract as {option}`providers.bootloader.installHook`.
        Setting this option wires the hook into the `script` `providers.bootloader` backend automatically.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    providers.bootloader.backend = "script";
    providers.bootloader.installHook = cfg.installHook;
  };
}
