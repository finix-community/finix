{
  config,
  extendModules,
  lib,
  pkgs,
  ...
}:

let
  vmGuest =
    { config, ... }:
    let
      cfg = config.virtualisation.qemu;
      hostName = config.networking.hostName;
      startScript = "run-${hostName}-vm";
    in
    {
      imports = [ ./qemu.nix ];

      virtualisation.qemu.extraArgs = [ "-nographic" ];

      # the host's disks do not exist in the guest, so replace every filesystem with a tmpfs root + host store shares
      fileSystems = lib.mkOverride 10 (
        cfg.guestFileSystems
        // {
          "/" = {
            device = "tmpfs";
            fsType = "tmpfs";
            options = [ "mode=755" ];
          };
        }
      );

      finit.ttys.${cfg.serialDevice} = {
        device = "/dev/${cfg.serialDevice}";
        baud = 115200;
        nowait = true;
      };

      system.build.vm =
        pkgs.runCommand "finix-vm-${hostName}"
          {
            preferLocalBuild = true;
            meta.mainProgram = startScript;
          }
          ''
            mkdir -p $out/bin
            ln -s ${config.system.topLevel} $out/system
            ln -s ${pkgs.writeShellScript startScript ''
              ${lib.optionalString (cfg.bootMode == "uefi") ''
                cp ${pkgs.OVMF.variables} ${hostName}-efi-vars.fd
                chmod 0644 ${hostName}-efi-vars.fd
              ''}
              exec ${lib.escapeShellArgs cfg.argv} -name ${lib.escapeShellArg hostName} "$@"
            ''} $out/bin/${startScript}
          '';
    };

  vmVariant = extendModules { modules = [ vmGuest ]; };
in
{
  options.virtualisation.vmVariant = lib.mkOption {
    description = ''
      Machine configuration to be added for the vm script produced by `nh os build-vm`.
    '';
    inherit (vmVariant) type;
    default = { };
    visible = "shallow";
  };

  config = {
    system.build.vm = lib.mkDefault config.virtualisation.vmVariant.system.build.vm;

    virtualisation.vmVariant.options.virtualisation.vmVariant = lib.mkOption {
      apply = _: throw "virtualisation.vmVariant.virtualisation.vmVariant is not supported";
    };
  };
}
