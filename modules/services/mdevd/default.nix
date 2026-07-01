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

  # Insert modules for devices with a modalias.
  # Use @ prefix to run via /bin/sh on add events.
  modaliasRule = ''-$MODALIAS=.* 0:0 660 @modprobe --quiet "$MODALIAS"'';

  # We need symlinks in /dev/disk/{by-id,by-label,by-uuid,by-partlabel,by-partuuid}
  # so we run this script for block device events.
  # Requires blkid from util-linux be on $PATH.
  #
  # Note: The by-id symlinks just use the device name as a placeholder.
  # Real unique IDs would require querying device serial numbers, etc.
  devDiskScript = pkgs.writeScript "mdevd-disk.sh" ''
    #!/bin/sh
    case "$ACTION" in
      add)
        # Create by-id symlink immediately (using device name as placeholder ID) -
        # cheap, no reason to defer it.
        mkdir -p /dev/disk/by-id
        ln -sf "../../$MDEV" "/dev/disk/by-id/$MDEV"

        # mdevd blocks its whole event loop until this script exits, so the blkid retry wait must run in the background, not foreground.
        (
          info=""
          for _try in 1 2 3 4 5; do
            info=$(blkid --output export "/dev/$MDEV" 2>/dev/null)
            [ -n "$info" ] && break
            sleep 0.2
          done

          echo "$info" | while IFS='=' read -r key value; do
            case "$key" in
              LABEL)
                mkdir -p /dev/disk/by-label
                ln -sf "../../$MDEV" "/dev/disk/by-label/$value"
                ;;
              UUID)
                mkdir -p /dev/disk/by-uuid
                ln -sf "../../$MDEV" "/dev/disk/by-uuid/$value"
                ;;
              PARTLABEL)
                mkdir -p /dev/disk/by-partlabel
                ln -sf "../../$MDEV" "/dev/disk/by-partlabel/$value"
                ;;
              PARTUUID)
                mkdir -p /dev/disk/by-partuuid
                ln -sf "../../$MDEV" "/dev/disk/by-partuuid/$value"
                ;;
            esac
          done
        ) &
        ;;
      remove)
        # Remove symlinks pointing to this device.
        # We scan directories instead of calling blkid since the device may already be gone.
        for dir in /dev/disk/by-id /dev/disk/by-label /dev/disk/by-uuid /dev/disk/by-partlabel /dev/disk/by-partuuid; do
          [ -d "$dir" ] || continue
          for link in "$dir"/*; do
            [ -L "$link" ] || continue
            target=$(readlink "$link")
            case "$target" in
              "../../$MDEV") rm -f "$link" ;;
            esac
          done
        done
        ;;
    esac
  '';

  # Use * prefix to run via /bin/sh on any action (add/remove).
  #
  # devDiskScript's own /nix/store path *is* present in the initrd, so referencing it directly here works for both the post-switch-root hotplug rules and the initrd coldplug rules.
  # What must NOT happen is depending on any *other* /nix/store path from within the script at runtime - see the writeScript/#!/bin/sh note above.
  devDiskRule = "-SUBSYSTEM=block;.* 0:${gidOf "disk"} 660 *${devDiskScript}";
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
        target = "/etc/mdevd-disk.sh";
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
      path = [
        config.programs.coreutils.package
        pkgs.execline
        pkgs.kmod
        pkgs.util-linux
      ];
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

    system.switch.inhibitors.device-manager = "mdevd";
  };
}
