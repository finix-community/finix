{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.incus;
in
{
  options.services.incus = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [incus](${pkgs.incus.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.incus-lts;
      defaultText = lib.literalExpression "pkgs.incus-lts";
      description = ''
        The package to use for `incus`.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
    ];

    finit.services.incusd = {
      description = "incus container hypervisor";
      conditions = [ "service/syslogd/ready" ];

      command = pkgs.writeShellApplication {
        name = "incusd";
        runtimeEnv = {
          INCUS_USBIDS_PATH = "${pkgs.hwdata}/share/hwdata/usb.ids";
        };
        runtimeInputs = with pkgs; [
          cfg.package

          qemu_kvm

          acl
          attr
          bash
          btrfs-progs
          cdrkit
          coreutils
          criu
          dnsmasq
          e2fsprogs
          findutils
          getent
          gnugrep
          gnused
          gnutar
          gptfdisk
          gzip
          iproute2
          iptables
          iw
          kmod
          libnvidia-container
          libxfs
          lvm2
          lxcfs
          minio
          minio-client
          nftables
          qemu-utils
          qemu_kvm
          rsync
          squashfs-tools-ng
          squashfsTools
          sshfs
          swtpm
          thin-provisioning-tools
          util-linux
          virtiofsd
          xdelta
          xz

          zfs
        ];

        text =
          "exec ${cfg.package}/bin/incusd --group incus-admin --syslog"
          + lib.optionalString cfg.debug " --debug";
      };

      kill = 30;

      # https://github.com/NixOS/nixpkgs/blob/92e1950ebadc72d89e7da09dd54f815c454cec0e/nixos/modules/virtualisation/incus.nix#L404-L407
      cgroup.settings."pids.max" = "max";
      rlimits = {
        memlock = "unlimited";
        nofile = 1048576;
        nproc = "unlimited";
      };
    };

    # https://github.com/lxc/incus/blob/f145309929f849b9951658ad2ba3b8f10cbe69d1/doc/reference/server_settings.md
    boot.kernel.sysctl = lib.mapAttrs (_: lib.mkDefault) {
      "fs.aio-max-nr" = 524288;
      "fs.inotify.max_queued_events" = 1048576;
      "fs.inotify.max_user_instances" = 1048576;
      "fs.inotify.max_user_watches" = 1048576;
      "kernel.dmesg_restrict" = 1;
      "kernel.keys.maxbytes" = 2000000;
      "kernel.keys.maxkeys" = 2000;
      "net.core.bpf_jit_limit" = 1000000000;
      "net.ipv4.neigh.default.gc_thresh3" = 8192;
      "net.ipv6.neigh.default.gc_thresh3" = 8192;
      "vm.max_map_count" = 262144;
    };

    boot.kernelModules = [
      "br_netfilter"
      "veth"
      "xt_comment"
      "xt_CHECKSUM"
      "xt_MASQUERADE"
      "vhost_vsock"
    ];

    # waiting on resolution from https://github.com/nikstur/userborn/issues/7
    users.users.root = {
      # match documented default ranges https://linuxcontainers.org/incus/docs/main/userns-idmap/#allowed-ranges
      # subUidRanges = [
      #   {
      #     startUid = 1000000;
      #     count = 1000000000;
      #   }
      # ];
      # subGidRanges = [
      #   {
      #     startGid = 1000000;
      #     count = 1000000000;
      #   }
      # ];
    };

    environment.etc.subuid.text = ''
      root:1000000:1000000000
    '';

    environment.etc.subgid.text = ''
      root:1000000:1000000000
    '';

    users.groups = {
      incus = { };
      incus-admin = { };
    };
  };
}
