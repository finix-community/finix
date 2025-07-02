{ config, pkgs, lib, ... }:
let
  cfg = config.boot.initrd;


  # Perform substitutions in all udev rules files.
  udevRulesFor = { name, udevPackages, udevPath, udev, binPackages }: pkgs.runCommand name
    { preferLocalBuild = true;
      allowSubstitutes = false;
      packages = lib.unique (map toString udevPackages);
    }
    ''
      mkdir -p $out
      shopt -s nullglob
      set +o pipefail

      # Set a reasonable $PATH for programs called by udev rules.
      echo 'ENV{PATH}="${udevPath}/bin:${udevPath}/sbin"' > $out/00-path.rules

      # Add the udev rules from other packages.
      for i in $packages; do
        echo "Adding rules for package $i"
        for j in $i/{etc,lib,/var/lib}/udev/rules.d/*; do
          echo "Copying $j to $out/$(basename $j)"
          cat $j > $out/$(basename $j)
        done
      done

      # Fix some paths in the standard udev rules.  Hacky.
      for i in $out/*.rules; do
        substituteInPlace $i \
          --replace-quiet \"/sbin/modprobe \"${pkgs.kmod}/bin/modprobe \
          --replace-quiet \"/sbin/mdadm \"${pkgs.mdadm}/sbin/mdadm \
          --replace-quiet \"/sbin/blkid \"${pkgs.util-linux}/sbin/blkid \
          --replace-quiet \"/bin/mount \"${pkgs.util-linux}/bin/mount \
          --replace-quiet /usr/bin/readlink ${pkgs.coreutils}/bin/readlink \
          --replace-quiet /usr/bin/cat ${pkgs.coreutils}/bin/cat \
          --replace-quiet /usr/bin/basename ${pkgs.coreutils}/bin/basename 2>/dev/null
      done

      echo -n "Checking that all programs called by relative paths in udev rules exist in ${udev}/lib/udev... "
      import_progs=$(grep 'IMPORT{program}="[^/$]' $out/* |
        sed -e 's/.*IMPORT{program}="\([^ "]*\)[ "].*/\1/' | uniq)
      run_progs=$(grep -v '^[[:space:]]*#' $out/* | grep 'RUN+="[^/$]' |
        sed -e 's/.*RUN+="\([^ "]*\)[ "].*/\1/' | uniq)
      for i in $import_progs $run_progs; do
        if [[ ! -x ${udev}/lib/udev/$i && ! $i =~ socket:.* ]]; then
          echo "FAIL"
          echo "$i is called in udev rules but not installed by udev"
          exit 1
        fi
      done
      echo "OK"

      echo -n "Checking that all programs called by absolute paths in udev rules exist... "
      import_progs=$(grep 'IMPORT{program}="/' $out/* |
        sed -e 's/.*IMPORT{program}="\([^ "]*\)[ "].*/\1/' | uniq)
      run_progs=$(grep -v '^[[:space:]]*#' $out/* | grep 'RUN+="/' |
        sed -e 's/.*RUN+="\([^ "]*\)[ "].*/\1/' | uniq)
      for i in $import_progs $run_progs; do
        if [[ ! -x $i ]]; then
          echo "FAIL"
          echo "$i is called in udev rules but is not executable or does not exist"
          exit 1
        fi
      done
      echo "OK"

      filesToFixup="$(for i in "$out"/*; do
        # list all files referring to (/usr)/bin paths, but allow references to /bin/sh.
        grep -P -l '\B(?!\/bin\/sh\b)(\/usr)?\/bin(?:\/.*)?' "$i" || :
      done)"

      if [ -n "$filesToFixup" ]; then
        echo "Consider fixing the following udev rules:"
        echo "$filesToFixup" | while read localFile; do
          remoteFile="origin unknown"
          for i in ${toString binPackages}; do
            for j in "$i"/*/udev/rules.d/*; do
              [ -e "$out/$(basename "$j")" ] || continue
              [ "$(basename "$j")" = "$(basename "$localFile")" ] || continue
              remoteFile="originally from $j"
              break 2
            done
          done
          refs="$(
            grep -o '\B\(/usr\)\?/s\?bin/[^ "]\+' "$localFile" \
              | sed -e ':r;N;''${s/\n/ and /;br};s/\n/, /g;br'
          )"
          echo "$localFile ($remoteFile) contains references to $refs."
        done
        exit 1
      fi
    '';

    mkMount = mnt: ''
      mkdir -p "$targetRoot${mnt.mountPoint}"
    '' + (if builtins.elem "bind" mnt.options then ''
      mount -o ${lib.concatStringsSep "," mnt.options} "$targetRoot${mnt.device}" "$targetRoot${mnt.mountPoint}"
    '' else ''
      mount -t ${mnt.fsType} -o ${lib.concatStringsSep "," mnt.options} "${mnt.device}" "$targetRoot${mnt.mountPoint}"
    '');

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
    ${lib.concatMapStringsSep "\n" mkMount (builtins.filter (builtins.getAttr "neededForBoot") (builtins.attrValues config.fileSystems))}

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

  fsPackages = config.boot.initrd.supportedFilesystems
    |> lib.filterAttrs (_: v: v.enable)
    |> lib.attrValues
    |> lib.catAttrs "packages"
    |> lib.flatten
    |> lib.unique
  ;

  path = pkgs.buildEnv {
    name = "initrd-path";
    paths =
      [
        pkgs.busybox
        pkgs.kmod
        (lib.hiPrio pkgs.util-linux.mount)
      ]
      ++ lib.optional config.services.udev.enable pkgs.eudev
      ++ lib.optionals config.services.mdevd.enable [
        config.services.mdevd.package
        pkgs.execline
        pkgs.s6-portable-utils
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

  modulesClosure = pkgs.makeModulesClosure {
    rootModules = config.boot.initrd.availableKernelModules ++ config.boot.initrd.kernelModules;
    kernel = config.system.modulesTree;
    firmware = config.hardware.firmware;
    allowMissing = false;
  };
in
{
  options.boot.initrd = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to enable the NixOS initial RAM disk (initrd). This may be
        needed to perform some initialisation tasks (like mounting
        network/encrypted file systems) before continuing the boot process.
      '';
    };

    compressor = lib.mkOption {
      default =
        if lib.versionAtLeast config.boot.kernelPackages.kernel.version "5.9"
        then "zstd"
        else "gzip"
      ;
      defaultText = lib.literalExpression "`zstd` if the kernel supports it (5.9+), `gzip` if not";
      type = with lib.types; either str (functionTo str);
      description = ''
        The compressor to use on the initrd image. May be any of:

        - The name of one of the predefined compressors, see {file}`pkgs/build-support/kernel/initrd-compressor-meta.nix` for the definitions.
        - A function which, given the nixpkgs package set, returns the path to a compressor tool, e.g. `pkgs: "''${pkgs.pigz}/bin/pigz"`
        - (not recommended, because it does not work when cross-compiling) the full path to a compressor tool, e.g. `"''${pkgs.pigz}/bin/pigz"`

        The given program should read data from stdin and write it to stdout compressed.
      '';
      example = "xz";
    };

    compressorArgs = lib.mkOption {
      default = null;
      type = with lib.types; nullOr (listOf str);
      description = "Arguments to pass to the compressor for the initrd image, or null to use the compressor's defaults.";
    };

    contents = lib.mkOption {
      type = with lib.types; listOf (submodule {
        options = {
          source = lib.mkOption {
            type = types.path;
          };
          target = lib.mkOption {
            type = with types; nullOr str;
            default = null;
          };
        };
      });
      description = ''
        Contents of the initrd.
      '';
    };

    fileSystemImportCommands = lib.mkOption {
      description = ''
        Lines of shell commands that are run after coldbooting
        the device-manager and before mounting file-systems.
      '';
      type = lib.types.lines;
      default = "";
      example = ''
        vgimport --all
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      description = "the initrd to use for your system... use a module to build one";
    };
  };

  config = {
    boot.initrd.supportedFilesystems = config.fileSystems
      |> lib.filterAttrs (_: fs: fs.neededForBoot)
      |> lib.mapAttrs' (_: v: lib.nameValuePair v.fsType { enable = true; })
    ;

    # stupid simple initrd, need a better implementation than this
    boot.initrd = {
      package = pkgs.makeInitrdNG {
        name = "simple-initrd";
        inherit (cfg) compressor compressorArgs;
        contents = map
          ({source, target}@pair:
            if target != null then pair else { inherit source; })
          cfg.contents;
      };
      contents = [
        { target = "/init"; source = init; }
        { target = "/bin"; source = "${path}/bin";  }
        { target = "/sbin"; source = "${path}/bin";  }
        { target = "/lib"; source = "${modulesClosure}/lib"; }
      ];
    };
  };
}
