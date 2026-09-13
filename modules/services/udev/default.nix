{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.udev;

  # HACK: finit binds the notify socket after forking... wait for it before exec'ing udevd
  notifyWait = pkgs.writeScript "finit-notify-wait" ''
    #!/bin/sh
    if [ -n "''${NOTIFY_SOCKET:-}" ]; then
      found=
      tries=0
      while [ -z "$found" ] && [ "$tries" -lt 100000 ]; do
        while read -r _ _ _ _ _ _ _ name; do
          if [ "$name" = "$NOTIFY_SOCKET" ]; then
            found=1
            break
          fi
        done < /proc/net/unix
        tries=$((tries + 1))
      done
    fi
    exec "$@"
  '';

  # udev has a 512-character limit for ENV{PATH}, so create a symlink tree to work around this
  udevPath = pkgs.buildEnv {
    name = "udev-path";
    paths = cfg.path;
    pathsToLink = [
      "/bin"
      "/sbin"
    ];
    ignoreCollisions = true;
  };

in
{
  options.services.udev = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [udev](${pkgs.systemdMinimal.meta.homepage}) as a system service.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.
      '';
    };

    packages = lib.mkOption {
      type = with lib.types; listOf path;
      default = [ ];
      description = ''
        List of packages containing {command}`udev` rules.
        All files found in
        {file}`«pkg»/etc/udev/rules.d` and
        {file}`«pkg»/lib/udev/rules.d`
        will be included.
      '';
      apply = map lib.getBin;
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.systemdMinimal;
      defaultText = lib.literalExpression "pkgs.systemdMinimal";
      description = ''
        The package to use for `udev`.
      '';
    };

    path = lib.mkOption {
      type = with lib.types; listOf path;
      default = [ ];
      description = ''
        Packages added to the {env}`PATH` environment variable when
        executing programs from Udev rules.

        coreutils, gnu{sed,grep}, util-linux
        automatically included.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.udev.path = [
      config.programs.coreutils.package
      pkgs.gnused
      pkgs.gnugrep
      pkgs.util-linux
      cfg.package
    ];

    finit.services.udevd = {
      description = "device event daemon";
      runlevels = "S12345789";
      command =
        "${notifyWait} ${cfg.package}/lib/systemd/systemd-udevd" + lib.optionalString cfg.debug " -D";
      notify = "systemd";
      pid = "udevd";
      log = true;
      nohup = true;
      cgroup.name = "system";
    };

    finit.run =
      let
        defaults = {
          runlevels = "S";
          conditions = "service/udevd/ready";
          log = true;
          cgroup.name = "init";
          extraConfig = "nowarn";

          priority = 1;
        };
      in
      {
        "udevadm@1" = defaults // {
          description = "";
          command = "${cfg.package}/bin/udevadm settle -t 0";
        };
        "udevadm@2" = defaults // {
          description = "";
          command = "${cfg.package}/bin/udevadm control --reload";
        };
        "udevadm@3" = defaults // {
          description = "requesting device events";
          command = "${cfg.package}/bin/udevadm trigger -c add -t devices";
        };
        "udevadm@4" = defaults // {
          description = "requesting subsystem events";
          command = "${cfg.package}/bin/udevadm trigger -c add -t subsystems";
        };
        "udevadm@5" = defaults // {
          description = "waiting for udev to finish";
          command = "${cfg.package}/bin/udevadm settle -t 30";
        };
      };

    environment.etc."udev/hwdb.bin" = lib.mkIf (cfg.packages != [ ]) {
      source =
        pkgs.runCommand "hwdb.bin"
          {
            __structuredAttrs = true;
            preferLocalBuild = true;
            allowSubstitutes = false;
            packages = lib.unique (map toString ([ pkgs.buildPackages.systemd ] ++ cfg.packages));
          }
          ''
            shopt -s nullglob

            mkdir -p etc/udev/hwdb.d
            for i in "''${packages[@]}"; do
              echo "adding hwdb files for package $i"
              for j in "$i"/{etc,lib,var/lib}/udev/hwdb.d/*; do
                # must be a copy, not a symlink: `--root` below chases links *within* the root
                cp "$j" "etc/udev/hwdb.d/$(basename "$j")"
              done
            done

            echo "generating hwdb database..."
            ${pkgs.buildPackages.systemd}/bin/systemd-hwdb --strict --root="$PWD" update
            mv etc/udev/hwdb.bin $out
          '';
    };

    environment.etc."udev/rules.d".source =
      pkgs.runCommand "udev-rules"
        {
          __structuredAttrs = true;
          preferLocalBuild = true;
          allowSubstitutes = false;
          packages = lib.unique (map toString ([ cfg.package ] ++ cfg.packages));
        }
        ''
          mkdir -p $out
          shopt -s nullglob

          # set a reasonable $PATH for programs called by udev rules
          echo 'ENV{PATH}="${udevPath}/bin:${udevPath}/sbin"' > $out/00-path.rules

          for i in "''${packages[@]}"; do
            echo "Adding rules for package $i"
            for j in "$i"/{etc,lib,var/lib}/udev/rules.d/*; do
              echo "Copying $j to $out/$(basename "$j")"
              cat "$j" > "$out/$(basename "$j")"
            done
          done

          # unused or problematic
          rm -f $out/99-systemd.rules $out/60-tpm2-id.rules

          # fix some paths in the standard udev rules
          for i in $out/*.rules; do
            substituteInPlace $i \
              --replace-quiet \"/sbin/modprobe \"${lib.getExe' pkgs.kmod "modprobe"} \
              --replace-quiet \"/sbin/mdadm \"${pkgs.mdadm}/sbin/mdadm \
              --replace-quiet \"/sbin/blkid \"${pkgs.util-linux}/sbin/blkid \
              --replace-quiet \"/bin/mount \"${pkgs.util-linux}/bin/mount \
              --replace-quiet /usr/bin/readlink ${lib.getExe' config.programs.coreutils.package "readlink"} \
              --replace-quiet /usr/bin/cat ${lib.getExe' config.programs.coreutils.package "cat"} \
              --replace-quiet /usr/bin/basename ${lib.getExe' config.programs.coreutils.package "basename"} 2>/dev/null
          done
        '';

    # where does this belong?
    system.activation.scripts.udevd = lib.mkIf config.boot.kernel.enable {
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

    system.switch.inhibitors.device-manager = "udev";

    # build out the default initramfs image
    boot.initrd = {
      finit.services.udevd = {
        command = "${notifyWait} ${cfg.package}/lib/systemd/systemd-udevd";
        notify = "systemd";
      };

      finit.run = {
        "udevadm@1" = {
          command = "${cfg.package}/bin/udevadm settle -t 0";
          conditions = "service/udevd/ready";
          priority = 200;
        };
        "udevadm@2" = {
          command = "${cfg.package}/bin/udevadm control --reload";
          conditions = "service/udevd/ready";
          priority = 210;
        };
        "udevadm@3" = {
          command = "${cfg.package}/bin/udevadm trigger -c add -t devices";
          conditions = "service/udevd/ready";
          priority = 220;
        };
        "udevadm@4" = {
          command = "${cfg.package}/bin/udevadm trigger -c add -t subsystems";
          conditions = "service/udevd/ready";
          priority = 230;
        };
        "udevadm@5" = {
          command = "${cfg.package}/bin/udevadm settle -t 30";
          conditions = "service/udevd/ready";
          priority = 240;
        };
      };

      contents = [
        { source = notifyWait; }
        {
          source = "${cfg.package}/bin/udevadm";
          dlopen = "recommended";
        }
        {
          # without the dlopen'd libkmod, MODALIAS autoloading silently stops
          source = "${cfg.package}/lib/systemd/systemd-udevd";
          dlopen = "recommended";
        }
      ]
      ++
        # minimal set of rules needed for initramfs
        map
          (v: {
            target = "/etc/udev/rules.d/${v}.rules";
            source = "${cfg.package}/lib/udev/rules.d/${v}.rules";
          })
          [
            "60-block"
            "60-cdrom_id"
            "60-persistent-storage"
            "75-net-description"
            "80-drivers"
          ]
      ++
        # helpers called by bare name, which udev resolves against its own libexec directory
        map
          (v: {
            source = "${cfg.package}/lib/udev/${v}";
            dlopen = "recommended";
          })
          [
            "ata_id"
            "cdrom_id"
            "scsi_id"
          ];
    };
  };
}
