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

  # TODO: respect log levels, be quiet
  init = pkgs.writeScript "init" ''
    #!/bin/sh

    # set -x

    targetRoot=/mnt-root

    fail() {
        # If starting stage 2 failed, allow the user to repair the problem
        # in an interactive shell.
        cat <<EOF

    An error occurred in stage 1 of the boot process, which must mount the
    root filesystem on \`$targetRoot' and then start stage 2.

    EOF

        exec setsid /bin/sh -c "exec /bin/sh < /dev/tty1 >/dev/tty1 2>/dev/tty1"
    }

    trap 'fail' 0

    echo
    echo "[1;32m<<< finix - stage 1 >>>[0m"
    echo

    # mount -a for early mount stuff (like /run, /proc, etc...)
    mkdir -p /dev /proc /tmp /run /sys

    # TODO: this should be defined under fileSystems or something, make use of fstab + mount -a or something
    mount -o defaults -t devtmpfs devtmpfs /dev
    mkdir -p /dev/pts /dev/shm
    mount -o mode=620 -t devpts devpts /dev/pts
    mount -o mode=0777 -t tmpfs tmpfs /dev/shm
    mount -o defaults -t proc proc /proc
    mount -o mode=0755,nosuid,nodev -t tmpfs tmpfs /run
    mount -o defaults -t sysfs sysfs /sys




    # Log the script output to /dev/kmsg or /run/log/stage-1-init.log.
    mkdir -p /tmp
    mkfifo /tmp/stage-1-init.log.fifo
    logOutFd=8 && logErrFd=9
    eval "exec $logOutFd>&1 $logErrFd>&2"
    if test -w /dev/kmsg; then
        tee -i < /tmp/stage-1-init.log.fifo /proc/self/fd/"$logOutFd" | while read -r line; do
            if test -n "$line"; then
                echo "<7>stage-1-init: [$(date)] $line" > /dev/kmsg
            fi
        done &
    else
        mkdir -p /run/log
        tee -i < /tmp/stage-1-init.log.fifo /run/log/stage-1-init.log &
    fi
    exec > /tmp/stage-1-init.log.fifo 2>&1




    # store args, want to be able to pass to the init system
    stage2Args="$@"

    # Process the kernel command line.
    export stage2Init=/init
    for o in $(cat /proc/cmdline); do
      case $o in
        init=*)
          set -- $(IFS==; echo $o)
          stage2Init=$2
          ;;
        root=*)
          # If a root device is specified on the kernel command
          # line, make it available through the symlink /dev/root.
          # Recognise LABEL= and UUID= to support UNetbootin.
          set -- $(IFS==; echo $o)
          if [ $2 = "LABEL" ]; then
            root="/dev/disk/by-label/$3"
          elif [ $2 = "UUID" ]; then
            root="/dev/disk/by-uuid/$3"
          else
            root=$2
          fi
          ln -s "$root" /dev/root
          ;;
      esac
    done


    # Load the required kernel modules.
    echo ${pkgs.kmod}/bin/modprobe > /proc/sys/kernel/modprobe
    for i in ${toString config.boot.initrd.kernelModules}; do
      echo "loading module $(basename $i)..."
      modprobe $i
    done

    echo "modalias stuff"
    find /sys/devices -name modalias -print0 | xargs -0 sort -u -z | xargs -0 modprobe -abq

    # Create device nodes in /dev.
    ln -sfn /proc/self/fd /dev/fd
    ln -sfn /proc/self/fd/0 /dev/stdin
    ln -sfn /proc/self/fd/1 /dev/stdout
    ln -sfn /proc/self/fd/2 /dev/stderr

    ${
      if config.services.udev.enable then
        ''
          echo "running udev..."

          udevd --daemon

          udevadm settle -t 0
          udevadm control --reload
          udevadm trigger -c add -t devices
          udevadm trigger -c add -t subsystems
          udevadm settle -t 30
        ''
      else if config.services.mdevd.enable then
        ''
          echo "coldplugging mdevd..."
          PATH=/bin mdevd -O 2 &
          mdevdPid=$!
          mdevd-coldplug -O 2
        ''
      else
        throw "no device manager for coldplug events enabled"
    }

    ${cfg.fileSystemImportCommands}

    # mount everything needed for boot
    ${lib.concatMapStringsSep "\n" mkMount (
      builtins.filter (builtins.getAttr "neededForBoot") (builtins.attrValues config.fileSystems)
    )}

    ${
      if config.services.udev.enable then
        ''
          # Stop udevd.
          udevadm control --exit

          echo "udevadm control --exit has run"
        ''
      else if config.services.mdevd.enable then
        ''
          kill $mdevdPid
        ''
      else
        throw "no device manager for coldplug events enabled"
    }

    # Reset the logging file descriptors.
    # Do this just before pkill, which will kill the tee process.
    exec 1>&$logOutFd 2>&$logErrFd
    eval "exec $logOutFd>&- $logErrFd>&-"


    echo "about to kill any remaining processes..."

    # Kill any remaining processes, just to be sure we're not taking any
    # with us into stage 2. But keep storage daemons like unionfs-fuse.
    #
    # Storage daemons are distinguished by an @ in front of their command line:
    # https://www.freedesktop.org/wiki/Software/systemd/RootStorageDaemons/
    for pid in $(pgrep -v -f '^@'); do
      # Make sure we don't kill kernel processes, see #15226 and:
      # http://stackoverflow.com/questions/12213445/identifying-kernel-threads
      readlink "/proc/$pid/exe" &> /dev/null || continue
      # Try to avoid killing ourselves.
      [ $pid -eq $$ ] && continue
      kill -9 "$pid"
    done


    # Restore /proc/sys/kernel/modprobe to its original value.
    echo /sbin/modprobe > /proc/sys/kernel/modprobe


    mkdir -m 0755 -p $targetRoot/proc $targetRoot/sys $targetRoot/dev $targetRoot/run

    mount --move /proc $targetRoot/proc
    mount --move /sys $targetRoot/sys
    mount --move /dev $targetRoot/dev
    mount --move /run $targetRoot/run

    echo "about to call switch_root..."

    exec env -i $(type -P switch_root) "$targetRoot" "$stage2Init" "$stage2Args"

    fail # should never be reached
  '';

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
    ]
    ++ lib.optional config.services.udev.enable pkgs.eudev
    ++ lib.optionals config.services.mdevd.enable [
      config.services.mdevd.package

      pkgs.execline
      pkgs.s6-portable-utils
      pkgs.util-linux
    ]
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
  config = lib.mkIf config.synit.enable {
    # stupid simple initrd, need a better implementation than this
    boot.initrd.contents = [
      {
        target = "/init";
        source = init;
      }
      {
        target = "/bin";
        source = "${path}/bin";
      }
      {
        target = "/sbin";
        source = "${path}/bin";
      }
    ];
  };
}
