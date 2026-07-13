{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.boot.initrd;

  grantAccess = cfg.emergencyAccess == true || lib.isString cfg.emergencyAccess;

  fsPackages = lib.unique (
    lib.flatten (
      lib.concatMap (v: lib.optional v.enable v.packages or [ ]) (
        lib.attrValues config.boot.initrd.supportedFilesystems
      )
    )
  );

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
    ++ lib.optionals config.services.gardendevd.enable [
      config.services.gardendevd.package
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
  options.boot.initrd = {
    emergencyAccess = lib.mkOption {
      type = with lib.types; nullOr (either bool (passwdEntry str));
      default = false;
      description = ''
        Set to `true` for unauthenticated emergency access to the initramfs
        rescue shell, and `false` or `null` for no access.

        Can also be set to a hashed super user password to allow
        authenticated access to the rescue mode.

        When access is denied, finix prints the failure reason on console
        and reboots after 10s instead of opening a shell.
      '';
    };
  };

  config.boot.initrd = {
    finit.run.setup-stdio = {
      priority = 100;
      script = ''
        ln -sfn /proc/self/fd    /dev/fd
        ln -sfn /proc/self/fd/0  /dev/stdin
        ln -sfn /proc/self/fd/1  /dev/stdout
        ln -sfn /proc/self/fd/2  /dev/stderr
      '';
    };

    finit.run.switch-root = {
      runlevels = "1";
      script = ''
        # process the kernel command line to find init=
        stage2Init=/init
        for o in $(cat /proc/cmdline); do
          case $o in
            init=*)
              set -- $(IFS==; echo $o)
              stage2Init=$2
              ;;
          esac
        done

        # TODO: modify `initctl switch-root` call in finit to have a proper return code
        if [ ! -d /sysroot ] || ! mountpoint -q /sysroot || [ ! -x "/sysroot$stage2Init" ]; then
          cat > /dev/console <<EOF

        ==========================================
        ${
          if !grantAccess then
            ''
              rescue shell is disabled

              rebooting in 10s
            ''
          else
            ''
              to diagnose:   initctl status; initctl cond dump
              to continue:   initctl switch-root /sysroot $stage2Init
              to reboot:     reboot -f
            ''
        }

        EOF
          ${
            if !grantAccess then
              ''
                sleep 10
                exec reboot -f
              ''
            else
              # exit non-zero so finit emits <run/switch-root/failure>,
              # which triggers the rescue tty in finit.conf
              ''
                exit 1
              ''
          }
        fi

        exec initctl switch-root /sysroot "$stage2Init"
      '';
    };

    finit.ttys.rescue = {
      runlevels = "1";
      device = "@console";
      conditions = "run/switch-root/failure";
      rescue = true;
    };

    contents = [
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
        target = "/etc/tmpfiles.d/finix.conf";
        source = pkgs.writeText "finix.conf" ''
          d /sysroot
          d /tmp
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
        source = pkgs.writeText "group" (
          lib.concatStringsSep "\n" (
            lib.concatMap (g: lib.optionals (g.gid != null) [ "${g.name}:x:${toString g.gid}:" ]) (
              lib.attrValues config.users.groups
            )
          )
        );
      }
      {
        target = "/etc/shadow";
        source =
          let
            password =
              if !grantAccess then
                "*"
              else if lib.isString cfg.emergencyAccess then
                cfg.emergencyAccess
              else
                "";
          in
          pkgs.writeText "shadow" ''
            root:${password}:1:0:99999:7:::
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
