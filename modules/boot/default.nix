{
  config,
  pkgs,
  lib,
  ...
}:
let
  initExecutables = {
    finit = "${config.finit.package}/bin/finit";
    dinit = "${config.dinit.package}/bin/dinit";
  };

  remountNixStore = pkgs.writeShellApplication {
    name = "remount-nix-store";
    runtimeInputs = [
      config.programs.coreutils.package
      pkgs.util-linux
    ];
    text = ''
      # Make the Nix store read-only after activation.
      # Silence chown/chmod to fail gracefully on a readonly filesystem
      # like squashfs.
      chown -f 0:30000 /nix/store || true
      chmod -f 1775 /nix/store || true
      if ! [[ "$(findmnt --noheadings --output OPTIONS /nix/store)" =~ ro(,|$) ]]; then
        mount --bind /nix/store /nix/store
        mount -o remount,ro,bind /nix/store
      fi
    '';
  };
in
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
    default = initExecutables.${config.system.init};
    defaultText = lib.literalExpression ''
      {
        finit = "''${config.finit.package}/bin/finit";
        dinit = "''${config.dinit.package}/bin/dinit";
      }.''${config.system.init}
    '';
    description = ''
      Executable run as stage-2 PID 1, symlinked as `${config.system.build.toplevel}/init`.
    '';
  };

  config = {
    finit.tasks = {
      remount-nix-store = {
        description = "remount the nix store in read only mode";
        runlevels = "S";
        command = remountNixStore;
      };

      # Dinit handles SIGINT from the kernel itself when it is PID 1, so its
      # Ctrl-Alt-Delete reboot path needs no generated service.
      # Finit exposes the same event as a condition, so keep its task here.
      ctrl-alt-del = {
        description = "rebooting system";
        runlevels = "12345789";
        conditions = "sys/key/ctrlaltdel";
        command = "${config.finit.package}/bin/initctl reboot";
      };
    };

    dinit.services.remount-nix-store = {
      type = "scripted";
      command = "${remountNixStore}/bin/remount-nix-store";
      targets = [ "local" ];
    };
  };
}
