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

  cfg = config.services.mdev;

  # Rules for the special standalone devices to be created at boot.
  specialRules =
    let
      tty = gidOf "tty";
      input = gidOf "input";
    in
    ''
      null         0:0 666
      zero         0:0 666
      full         0:0 666
      random       0:0 444
      urandom      0:0 444
      hwrandom     0:0 444

      ptmx         0:${tty}           666
      pty.*        0:${tty}           660
      tty          0:${tty}           666
      tty[0-9]+    0:${tty}           660

      vcsa[0-9]*   0:${tty}           660
      ttyS[0-9]*   0:${gidOf "uucp"}  660

      snd/.*       0:${gidOf "audio"} 660         @${libudev-zero-helper}/bin/helper
      dri/.*       0:${gidOf "video"} 660

      video[0-9]+  0:${gidOf "video"} 660         @${libudev-zero-helper}/bin/helper
      input/.*     0:${input}         660         @${libudev-zero-helper}/bin/helper

      event[0-9]+  0:${input}         660 =input/ @${libudev-zero-helper}/bin/helper
      mouse[0-9]+  0:${input}         660 =input/ @${libudev-zero-helper}/bin/helper
      js[0-9]+     0:${input}         660 =input/ @${libudev-zero-helper}/bin/helper
      mice         0:${input}         660 =input/ @${libudev-zero-helper}/bin/helper
   '';

  # Insert modules for devices with a modalias.
  modaliasRule = ''-$MODALIAS=.* 0:0 660 @${pkgs.kmod}/bin/modprobe --quiet "$MODALIAS"'';

  # https://github.com/illiliti/libudev-zero/blob/master/contrib/helper.c
  libudev-zero-helper = pkgs.writeCBin "helper" ''
    /*
     * Copyright (c) 2020-2021 illiliti <illiliti@protonmail.com>
     * SPDX-License-Identifier: ISC
     * 
     * Permission to use, copy, modify, and/or distribute this software for any
     * purpose with or without fee is hereby granted, provided that the above
     * copyright notice and this permission notice appear in all copies.
     * 
     * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
     * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
     * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
     * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
     * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
     * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
     * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
     *
     *
     * Construct uevent message from environment and send it to 0x4 netlink group.
     */

    #include <stdio.h>
    #include <string.h>
    #include <unistd.h>
    #include <sys/socket.h>
    #include <linux/netlink.h>

    int main(int argc, char **argv)
    {
        struct sockaddr_nl sa = {0};
        struct msghdr hdr = {0};
        struct iovec iov = {0};
        extern char **environ;
        char buf[8192];
        size_t len;
        int i, fd;

        iov.iov_base = buf;
        iov.iov_len = 0;

        for (i = 0; environ[i]; i++) {
            if (strncmp(environ[i], "PATH=", 5) == 0 ||
                strncmp(environ[i], "HOME=", 5) == 0) {
                continue;
            }

            len = strlen(environ[i]) + 1;

            if (iov.iov_len + len > sizeof(buf)) {
                fprintf(stderr, "%s: uevent exceeds buffer size", argv[0]);
                return 1;
            }

            memcpy(buf + iov.iov_len, environ[i], len);
            iov.iov_len += len;
        }

        sa.nl_family = AF_NETLINK;
        sa.nl_groups = 0x4; // XXX

        hdr.msg_name = &sa;
        hdr.msg_namelen = sizeof(sa);
        hdr.msg_iov = &iov;
        hdr.msg_iovlen = 1;

        fd = socket(AF_NETLINK, SOCK_DGRAM, NETLINK_KOBJECT_UEVENT);

        if (fd == -1) {
            perror("socket");
            return 1;
        }

        if (sendmsg(fd, &hdr, 0) == -1) {
            perror("sendmsg");
            close(fd);
            return 1;
        }

        close(fd);
        return 0;
    }
  '';

  # We need symlinks in /dev/disk/{by-id,by-label,by-uuid,by-partlabel,by-partuuid}
  # so we run this script for block device events.
  # Requires blkid from util-linux be on $PATH.
  #
  # Note: The by-id symlinks just use the device name as a placeholder.
  # Real unique IDs would require querying device serial numbers, etc.
  devDiskScript = pkgs.writeScript "mdev-disk.sh" ''
    #!/bin/sh
    case "$ACTION" in
      add)
        # Create by-id symlink (using device name as placeholder ID)
        mkdir -p /dev/disk/by-id
        ln -sf "../../$MDEV" "/dev/disk/by-id/$MDEV"

        # Create by-label, by-uuid, by-partlabel and by-partuuid symlinks from blkid output
        blkid --output export "/dev/$MDEV" 2>/dev/null | while IFS='=' read -r key value; do
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
        ;;
      remove) # Remove symlinks pointing to this device.
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
  devDiskRule = ''
    [hs]d[a-z][0-9]* 0:${gidOf "disk"} 660 *${devDiskScript}
    nvme[0-9]n[0-9]*p[0-9]* 0:${gidOf "disk"} 660 *${devDiskScript}
  '';
in
{
  options.services.mdev = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [mdev](${pkgs.busybox.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.busybox;
      defaultText = lib.literalExpression "pkgs.busybox";
      description = ''
        The package to use for `mdev`.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.
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
    services.mdev = {
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

    environment.etc."mdev.conf".text = config.services.mdev.hotplugRules;

    finit.tasks.register-hotplug = {
      description = "Registering kernel hotplug";
      command = "echo ${cfg.package}/bin/mdev > /proc/sys/kernel/hotplug";
      runlevels = "S";
      cgroup.name = "init";
      log = true;
    };

    # We need(?) this to be blocking so that everything is loaded before coldplug.
    # Crucially, colplugging mdev does *not* trigger our modalias rule
    #
    # https://lists.busybox.net/pipermail/busybox/2014-September/081780.html
    finit.run.modalias-load = {
      description = "Load modules for coldplugged devices";
      command = "${pkgs.writeShellScript "modalias-load" ''
        aliases=$(find /sys/devices -name modalias -type f | xargs -r cat | sort -u)
        echo "$aliases" | xargs -r -P"$(nproc)" -n1 ${pkgs.kmod}/bin/modprobe -q
        exit 0
      ''}";
      runlevels = "S";
      conditions = "task/register-hotplug/success";
      cgroup.name = "init";
      log = true;
    };

    finit.tasks.coldplug = {
      description = "Cold plugging system";
      command =
        "${cfg.package}/bin/busybox mdev -s"
        + lib.optionalString cfg.debug " -v";
      runlevels = "S";
      conditions = "run/modalias-load/success";
      cgroup.name = "init";
      log = true;
    };

    system.activation.scripts.mdev = lib.mkIf config.boot.kernel.enable {
      text = ''
        # Allow the kernel to find our firmware.
        if [ -e /sys/module/firmware_class/parameters/path ]; then
          echo -n "${config.hardware.firmware}/lib/firmware" > /sys/module/firmware_class/parameters/path
        fi
      '';
    };

    system.switch.inhibitors.device-manager = "mdev";

    boot.kernelPatches = [
      {
        name = "uevent-helper";
        patch = null;
        structuredExtraConfig = {
          UEVENT_HELPER = lib.mkForce lib.kernel.yes;
        };
      }
    ];

    # build out the default initramfs image
    boot.initrd = {
      finit.run.register-hotplug = {
        command = "echo ${cfg.package}/bin/mdev > /proc/sys/kernel/hotplug";
        priority = 200;
      };

      # TODO: always reports as fail, maybe wrap it as seen in the comment?
      finit.run.modalias-load = {
        # command = "/bin/sh -c 'find /sys/devices -name modalias -type f | xargs -r cat | sort -u | xargs -r -n1 modprobe -q'";
        command = "find /sys/devices -name modalias -type f | xargs -r cat | sort -u | xargs -r -n1 modprobe -q";
        priority = 210;
      };

      finit.run.coldplug = {
        command = "mdev -s";
        priority = 220;
      };

      contents = [
        {
          target = "/etc/mdev.conf";
          source = pkgs.writeText "mdev.conf" config.services.mdev.coldplugRules;
        }
        {
          source = devDiskScript;
          target = "/etc/mdev-disk.sh";
        }
      ];
    };
  };
}
