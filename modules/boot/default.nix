{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./bootspec.nix
    ./efi.nix
    ./initrd.nix
    ./kernel.nix
    ./sysctl.nix
  ];

  options.boot.init = lib.mkOption {
    type = lib.types.path;
    default = "${config.finit.package}/bin/finit";
    defaultText = lib.literalExpression ''"''${config.finit.package}/bin/finit"'';
    description = ''
      Executable run as stage-2 PID 1, symlinked as `''${config.system.build.toplevel}/init`.
    '';
  };

  config = {
    finit.tasks.remount-nix-store = {
      description = "remount the nix store in read only mode";
      runlevel = "S";
      path = [
        config.programs.coreutils.package
        pkgs.util-linux
      ];
      script = ''
        # Make /nix/store a read-only bind mount to enforce immutability of
        # the Nix store.  Note that we can't use "chown root:nixbld" here
        # because users/groups might not exist yet.
        # Silence chown/chmod to fail gracefully on a readonly filesystem
        # like squashfs.
        chown -f 0:30000 /nix/store || true
        chmod -f 1775 /nix/store || true

        # Ensure that we pick the "top" (i.e. last) mount so we don't get a false positive for a lower mount.
        current_opts="$(findmnt --direction backward --first-only --noheadings --output OPTIONS /nix/store)"
        case "$current_opts" in
          # matches '$opt', foo,$opt', '$opt,foo', 'foo,$opt,bar'
          ro | *,ro | ro,* | *,ro,*) ;;
          *)
            mount --bind /nix/store /nix/store
            mount -o remount,ro,bind /nix/store
            ;;
        esac
      '';
    };

    # task to run if ctrl-alt-del is pressed - this condition is asserted by finit upon receiving SIGINT (from the kernel).
    finit.tasks.ctrl-alt-del = {
      description = "rebooting system";
      runlevel = "12345789";
      conditions = "sys/key/ctrlaltdel";
      command = "${config.finit.package}/bin/initctl reboot";
    };
  };
}
