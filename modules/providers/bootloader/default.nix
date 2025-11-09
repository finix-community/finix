{ pkgs, lib, ... }:
{
  options.providers.bootloader = {
    backend = lib.mkOption {
      type = lib.types.enum [ ];
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
}
