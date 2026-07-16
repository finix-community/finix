{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./bootspec.nix
    ./initrd.nix
    ./kernel.nix
    ./modprobe.nix
    ./sysctl.nix
  ];

  options.boot.init = lib.mkOption {
    type = lib.types.path;
    default = "${config.finit.package}/bin/finit";
    defaultText = lib.literalExpression ''"''${config.finit.package}/bin/finit"'';
    description = ''
      Executable run as stage-2 PID 1, symlinked as `${config.system.build.toplevel}/init`.
    '';
  };

  config = {
    finit.tasks = lib.mkIf config.finit.enable {
      remount-nix-store = {
        description = "remount the nix store in read only mode";
        runlevels = "S";
        command = pkgs.writeShellApplication {
          name = "remount-nix-store.sh";
          runtimeInputs = [
            config.programs.coreutils.package
            pkgs.util-linux
          ];
          text = ''
            #!${pkgs.runtimeShell}

            # Make /nix/store a read-only bind mount to enforce immutability of
            # the Nix store.  Note that we can't use "chown root:nixbld" here
            # because users/groups might not exist yet.
            # Silence chown/chmod to fail gracefully on a readonly filesystem
            # like squashfs.
            chown -f 0:30000 /nix/store
            chmod -f 1775 /nix/store
            if ! [[ "$(findmnt --noheadings --output OPTIONS /nix/store)" =~ ro(,|$) ]]; then
              mount --bind /nix/store /nix/store
              mount -o remount,ro,bind /nix/store
            fi
          '';
        };
      };

      # task to run if ctrl-alt-del is pressed - this condition is asserted by finit upon receiving SIGINT (from the kernel).
      ctrl-alt-del = {
        description = "rebooting system";
        runlevels = "12345789";
        conditions = "sys/key/ctrlaltdel";
        command = "${config.finit.package}/bin/initctl reboot";
      };
    };
  };
}
