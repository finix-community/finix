{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkIf
    mkOption
    types
    ;

  writeExeclineScript = pkgs.execline.writeScript;
  gidOf = name: toString config.ids.gids.${name};

  cfg = config.services.mdevd;

  # Rules for the special standalone devices to be created at boot.
  specialRules =
    let
      tty = gidOf "tty";
    in
    ''
      null      0:0 666
      zero      0:0 666
      full      0:0 666
      random    0:0 444
      urandom   0:0 444
      hwrandom  0:0 444

      ptmx        0:${tty} 666
      pty.*       0:${tty} 660
      tty         0:${tty} 666
      tty[0-9]+   0:${tty} 660

      vcsa[0-9]*  0:${tty} 660
      ttyS[0-9]*  0:${gidOf "uucp"} 660

      snd/.*      0:${gidOf "audio"} 660

      dri/.*      0:${gidOf "video"} 660
      video[0-9]+ 0:${gidOf "video"} 660
    '';

  # Insert modules for devices.
  modaliasRule = "-$MODALIAS=.* 0:0 660 +importas m MODALIAS modprobe --quiet $m";

  # We need symlinks in /dev/disk/{by-id,by-label,by-uuid}
  # so we run this script for block device events.
  # Requires blkid from util-linux be on $PATH.
  devDiskScript = writeExeclineScript "mdevd-disk.el" "" ''
    multisubstitute {
      importas -S ACTION
      importas -S MDEV
    }
    case $ACTION
    {
      add {
        # Udev compatibility hack.
        foreground { s6-mkdir -p /dev/disk/by-id }
        foreground { s6-ln -s ../../$MDEV /dev/disk/by-id/$MDEV }

        forbacktickx -pE LINE { blkid --output export /dev/$MDEV }
        case -N $LINE {
          ^LABEL=(.*) {
            foreground { s6-mkdir -p /dev/disk/by-label }
            importas -S 1
            s6-ln -s ../../$MDEV /dev/disk/by-label/$1
          }
          ^UUID=(.*) {
            foreground { s6-mkdir -p /dev/disk/by-uuid }
            importas -S 1
            s6-ln -s ../../$MDEV /dev/disk/by-uuid/$1
          }
        }
      }
      remove {
        foreground { s6-rmrf /dev/disk/by-id/$MDEV }
        forbacktickx -pE LINE { blkid --output export /dev/$MDEV }
        case -N $LINE {
          ^LABEL=(.*) { importas -S 1 s6-rmrf /dev/disk/by-label/$1 }
           ^UUID=(.*) { importas -S 1 s6-rmrf /dev/disk/by-uuid/$1  }
        }
      }
    }
  '';

  devDiskRule = "-SUBSYSTEM=block;.* 0:${gidOf "disk"} 660 &${devDiskScript}";
in
{
  options.services.mdevd = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [mdevd](${pkgs.mdevd.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.mdevd;
      defaultText = lib.literalExpression "pkgs.mdevd";
      description = ''
        The package to use for `mdevd`.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.
      '';
    };

    nlgroups = lib.mkOption {
      type = with lib.types; nullOr ints.unsigned;
      default = null;
      description = ''
        After `mdevd` has handled the uevents, rebroadcast them to the netlink groups identified
        by the mask {option}`nlgroups`.

        ::: {.note}
        A value of `4` will make the daemon rebroadcast kernel uevents to `libudev-zero`.
        :::
      '';
    };

    hotplugRules = mkOption {
      type = types.lines;
      description = ''
        Mdevd rules for hotplug events.
        These rules are active after the initial `mdevd` daemon
        has coldbooted with the `services.mdevd.coldplug` rules.
      '';
    };

    coldplugRules = mkOption {
      type = types.lines;
      description = ''
        Mdeved rules for coldplug events during the initramfs stage of booting.
      '';
    };
  };

  config = mkIf cfg.enable {

    # Populate with boot rules.
    services.mdevd = {
      hotplugRules = lib.mkMerge [
        # fallthrough rules at the top
        (lib.mkOrder 250 modaliasRule)
        (lib.mkBefore devDiskRule)
        specialRules
      ];
      coldplugRules = lib.concatLines [
        modaliasRule
        specialRules
        devDiskRule
      ];
    };

    # Mdevd coldplugs the system during the stage-1 init in initramfs.
    # See ../../boot/initrd/default.nix
    boot.initrd.contents = [
      {
        target = "/etc/mdev.conf";
        source = pkgs.writeText "mdev.conf" config.services.mdevd.coldplugRules;
      }
      {
        source = devDiskScript;
        target = "/etc/dev-disk.el";
      }
    ];

    environment.etc."mdev.conf".text = config.services.mdevd.hotplugRules;

    finit.services.mdevd = {
      description = "device event daemon (mdevd)";
      command =
        "${cfg.package}/bin/mdevd -D %n -F /run/current-system/firmware -f ${
          config.environment.etc."mdev.conf".source
        }"
        + lib.optionalString (cfg.nlgroups != null) " -O ${toString cfg.nlgroups}"
        + lib.optionalString cfg.debug " -v 3";
      runlevels = "S12345789";
      cgroup.name = "init";
      notify = "s6";
      log = true;

      # TODO: now we're hijacking `env` and no one else can use it...
      env = pkgs.writeText "mdevd.env" ''
        PATH="${
          lib.makeBinPath [
            pkgs.s6-portable-utils
            pkgs.coreutils
            pkgs.execline
            pkgs.kmod
            pkgs.util-linux
          ]
        }:$PATH"
      '';
    };

    finit.run.coldplug = {
      description = "cold plugging system";
      command =
        "${cfg.package}/bin/mdevd-coldplug"
        + lib.optionalString (cfg.nlgroups != null) " -O ${toString cfg.nlgroups}"
        + lib.optionalString cfg.debug " -v 3";
      runlevels = "S";
      conditions = "service/mdevd/ready";
      cgroup.name = "init";
      log = true;
    };

    # TODO: share between udev and mdevd
    system.activation.scripts.mdevd = lib.mkIf config.boot.kernel.enable {
      text = ''
        # The deprecated hotplug uevent helper is not used anymore
        if [ -e /proc/sys/kernel/hotplug ]; then
          echo "" > /proc/sys/kernel/hotplug
        fi

        # Allow the kernel to find our firmware.
        if [ -e /sys/module/firmware_class/parameters/path ]; then
          echo -n "${config.hardware.firmware}/lib/firmware" > /sys/module/firmware_class/parameters/path
        fi
      '';
    };

    # Start a hotpluging mdevd after the stage-2 init.
    synit.core.daemons.mdevd = {
      argv = [
        "${cfg.package}/bin/mdevd"
        "-D"
        "3"
        "-F"
        "/run/current-system/firmware"
        # TODO: reload on SIGHUP.
        "-f"
        "/etc/mdev.conf"
      ]
      ++ lib.optionals (cfg.nlgroups != null) [
        "-O"
        (toString cfg.nlgroups)
      ]
      ++ lib.optionals cfg.debug [
        "-v"
        "3"
      ];
      readyOnNotify = 3;
      path = with pkgs; [
        kmod
        util-linux
      ];
      # Upstream claims mdevd is terse enough to run
      # without a dedicated logging destination.
      logging.enable = false;
    };

    # Hold core back until another coldplug completes.
    synit.core.daemons.mdevd-coldplug = {
      argv = [
        "${cfg.package}/bin/mdevd-coldplug"
      ]
      ++ lib.optionals (cfg.nlgroups != null) [
        "-O"
        (toString cfg.nlgroups)
      ]
      ++ lib.optionals cfg.debug [
        "-v"
        "3"
      ];
      restart = "on-error";
      requires = [
        {
          key = [
            "daemon"
            "mdevd"
          ];
        }
      ];
      logging.enable = false;
    };
  };
}
