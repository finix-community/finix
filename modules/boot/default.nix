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

  options = {
    boot.init = lib.mkOption {
      type = lib.types.path;
      default = "${config.finit.package}/bin/finit";
      defaultText = lib.literalExpression ''"''${config.finit.package}/bin/finit"'';
      description = ''
        Executable run as stage-2 PID 1, symlinked as `''${config.system.build.toplevel}/init`.
      '';
    };

    boot.nixStoreMountOpts = lib.mkOption {
      type = lib.types.listOf lib.types.nonEmptyStr;
      default = [
        "ro"
        "nosuid"
        "nodev"
      ];
      description = ''
        Defines the mount options used on a bind mount for {file}`/nix/store`.
        This affects the whole system except the nix store daemon, which will undo the bind mount.

        `ro` enforces immutability of the Nix store.
        The store daemon should already not put device mappers or suid binaries in the store,
        meaning `nosuid` and `nodev` enforce what should already be the case.
      '';
    };
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
        # Give /nix/store the defined mount options.
        # Note that we can't use "chown root:nixbld" here
        # because users/groups might not exist yet.

        # Silence chown/chmod to fail gracefully on a readonly filesystem
        # like squashfs.
        chown -f 0:30000 /nix/store || true
        chmod -f 1775 /nix/store || true

        missing_opts=""
        # Ensure that we pick the "top" (i.e. last) mount so we don't get a false positive for a lower mount.
        current_opts="$(findmnt --direction backward --first-only --noheadings --output OPTIONS /nix/store)"
        for opt in ${lib.escapeShellArgs config.boot.nixStoreMountOpts}; do
          case "$current_opts" in
            # matches '$opt', foo,$opt', '$opt,foo', 'foo,$opt,bar'
            "$opt" | *,"$opt" | "$opt",* | *,"$opt",*) ;;
            *) missing_opts="''${missing_opts:+''${missing_opts},}''${opt}" ;;
          esac
        done

        if [ -n "$missing_opts" ]; then
          mount --bind /nix/store /nix/store
          # apply the missing mount options
          mount -o "remount,$missing_opts,bind" /nix/store
        fi
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
