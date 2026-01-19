{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.boot.initrd;

  mkMount =
    mnt:
    ''
      mkdir -p "$targetRoot${mnt.mountPoint}"
    ''
    + (
      if builtins.elem "bind" mnt.options then
        ''
          mount -o ${lib.concatStringsSep "," mnt.options} "$targetRoot${mnt.device}" "$targetRoot${mnt.mountPoint}"
        ''
      else
        ''
          mount -t ${mnt.fsType} -o ${lib.concatStringsSep "," mnt.options} "${mnt.device}" "$targetRoot${mnt.mountPoint}"
        ''
    );

  fsPackages =
    config.boot.initrd.supportedFilesystems
    |> lib.filterAttrs (_: v: v.enable)
    |> lib.attrValues
    |> lib.catAttrs "packages"
    |> lib.flatten
    |> lib.unique;

  path = pkgs.buildEnv {
    name = "initrd-path";
    paths = [
      pkgs.busybox
      pkgs.kmod
      (lib.hiPrio pkgs.util-linux.mount)
      pkgs.bash
      config.finit.package
    ]
    ++ lib.optionals config.services.mdevd.enable [
      config.services.mdevd.package
      pkgs.execline
      pkgs.util-linux
    ]
    ++ lib.optionals config.services.udev.enable [ config.services.udev.package ]
    ++ fsPackages;
    pathsToLink = [
      "/bin"
    ];

    ignoreCollisions = true;

    postBuild = ''
      # Remove wrapped binaries, they shouldn't be accessible via PATH.
      find $out/bin -maxdepth 1 -name ".*-wrapped" -type l -delete
    '';
  };
in
{
  config = lib.mkIf config.finit.enable {
    boot.initrd.contents = [
      {
        target = "/init";
        source = "${config.finit.package}/bin/finit";
      }
      {
        target = "/bin";
        source = "${path}/bin";
      }
      {
        target = "/sbin";
        source = "${path}/bin";
      }
      {
        target = "/etc/os-release";
        source = pkgs.writeText "os-release" ''
          PRETTY_NAME="finix - stage 1"
        '';
      }
      {
        target = "/etc/modules-load.d/finix.conf";
        source = pkgs.writeText "finix.conf" ''

          ${lib.concatStringsSep "\n" config.boot.initrd.kernelModules}
        '';
      }
      {
        target = "/usr/local/bin/finix-fs-import";
        source = pkgs.writeScript "finix-fs-import" ''
          #!/bin/sh

          ${cfg.fileSystemImportCommands}
        '';
      }
      {
        target = "/etc/tmpfiles.d/finix.conf";
        source = pkgs.writeText "finix.conf" ''
          d /sysroot
          d /tmp
        '';
      }
      {
        target = "/usr/local/bin/finix-mount-all";
        source = pkgs.writeScript "finix-mount-all" ''
          #!/bin/sh

          targetRoot=/sysroot

          ${lib.concatMapStringsSep "\n" mkMount (
            lib.filter (lib.getAttr "neededForBoot") (lib.attrValues config.fileSystems)
          )}
        '';
      }
      {
        target = "/usr/local/bin/finix-setup-stdio";
        source = pkgs.writeScript "finix-setup-stdio" ''
          #!/bin/sh
          set -e

          ln -sfn /proc/self/fd    /dev/fd
          ln -sfn /proc/self/fd/0  /dev/stdin
          ln -sfn /proc/self/fd/1  /dev/stdout
          ln -sfn /proc/self/fd/2  /dev/stderr
        '';
      }
      {
        target = "/usr/local/bin/finix-switch-root";
        source = pkgs.writeScript "finix-switch-root" ''
          #!/bin/sh

          # Process the kernel command line.
          export stage2Init=/init
          for o in $(cat /proc/cmdline); do
            case $o in
              init=*)
                set -- $(IFS==; echo $o)
                stage2Init=$2
                ;;
            esac
          done

          echo "stage2Init: $stage2Init"

          exec initctl switch-root /sysroot "$stage2Init"
        '';
      }
      {
        target = "/etc/finit.conf";
        source = pkgs.writeText "finit.conf" ''
          PATH=/bin:/sbin:/usr/bin:/usr/local/bin

          readiness none
          runlevel 1

          run [S] finix-setup-stdio

          ${lib.optionalString config.services.udev.enable ''
            run [S] name:udevadm :1 <service/udevd/ready> udevadm settle -t 0
            run [S] name:udevadm :2 <service/udevd/ready> udevadm control --reload
            run [S] name:udevadm :3 <service/udevd/ready> udevadm trigger -c add -t devices
            run [S] name:udevadm :4 <service/udevd/ready> udevadm trigger -c add -t subsystems
            run [S] name:udevadm :5 <service/udevd/ready> udevadm settle -t 30
          ''}

          ${lib.optionalString config.services.mdevd.enable ''
            run [S] name:coldplug <service/mdevd/ready> mdevd-coldplug -O 2
          ''}

          task [S] name:fs-import \
            ${lib.optionalString config.services.mdevd.enable "<run/coldplug/success>"} \
            ${lib.optionalString config.services.udev.enable "<run/udevadm:5/success>"} \
            finix-fs-import

          task [S] name:mount-all <task/fs-import/success> finix-mount-all

          ${lib.optionalString config.services.mdevd.enable ''
            service [S] name:mdevd notify:s6 <!> mdevd -D %n -O 2
          ''}

          ${lib.optionalString config.services.udev.enable ''
            service [S] <!> notify:s6 /bin/udevd --ready-notify=%n
          ''}

          run [1] finix-switch-root
        '';
      }
      {
        target = "/etc/fstab";
        source = pkgs.writeText "fstab" ''
          # fstab.conf
          # tmpfs /run/wrappers tmpfs mode=755,nodev,size=50%,X-mount.mkdir 0 0

          tmpfs /run tmpfs mode=0755,nodev,nosuid,X-mount.mkdir 0 0
        '';
      }
      {
        target = "/etc/passwd";
        source = pkgs.writeText "passwd" ''
          root:x:0:0:root:/root:/bin/sh
        '';
      }
      {
        target = "/etc/group";
        source = pkgs.writeText "group" ''
          root:x:0:
        '';
      }
      {
        target = "/etc/shadow";
        source = pkgs.writeText "shadow" ''
          root::1:0:99999:7:::
        '';
      }
      { source = "${config.finit.package}/libexec"; }
      { source = "${config.finit.package}/lib/finit/"; }
      { source = "${config.finit.package}/lib/finit/plugins/bootmisc.so"; }
      { source = "${config.finit.package}/lib/finit/plugins/modules-load.so"; }
      { source = "${config.finit.package}/lib/finit/plugins/netlink.so"; }
      { source = "${config.finit.package}/lib/finit/plugins/pidfile.so"; }
      { source = "${config.finit.package}/lib/finit/plugins/procps.so"; }
      { source = "${config.finit.package}/lib/finit/plugins/sys.so"; }
      { source = "${config.finit.package}/lib/finit/plugins/tty.so"; }
      { source = "${config.finit.package}/lib/finit/plugins/usr.so"; }
      { source = "${config.finit.package}/lib/finit/rescue.conf"; }
      { source = "${config.finit.package}/lib/finit/tmpfiles.d"; }
      { source = "${config.finit.package}/lib/tmpfiles.d"; }
    ];
  };
}
