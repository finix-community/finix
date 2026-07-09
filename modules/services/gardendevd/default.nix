{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.gardendevd;

  package = pkgs.gardendevd.overrideAttrs (old: {
    version = "0.2-unstable-2026-07-03";

    src = old.src.override {
      tag = null;
      rev = "ec73dc569382404bc6620c9857b7e09206bc282e";
      hash = "sha256-8VOJFz5QtlyLbAf87rtNXSvnrfPoyQVAKwuD+YkfzdQ=";
    };

    mesonFlags = [
      (lib.mesonEnable "dracut" false)
      (lib.mesonEnable "uaccess" true)
    ];
  });
in
{
  options.services.gardendevd = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [gardendevd](${cfg.package.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = package;
      defaultText = lib.literalExpression "pkgs.gardendevd";
      description = ''
        The package to use for `gardendevd`.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.
      '';
    };

    extraArgs = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = ''
        Additional arguments to pass to `gardendevd`.
      '';
    };

    path = lib.mkOption {
      type = with lib.types; listOf path;
      default = [ ];
      description = ''
        Packages added to the {env}`PATH` environment variable when
        executing programs from udev rules.

        coreutils, gnu{sed,grep}, util-linux and kmod are
        automatically included.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    services.gardendevd.extraArgs = [
      "-K"
      "-v"
      (if cfg.debug then "debug" else "info")
    ];

    services.gardendevd.path = [
      config.programs.coreutils.package
      pkgs.gnugrep
      pkgs.gnused
      pkgs.kmod
      pkgs.util-linux
    ];

    # contribute gardendevd's bundled rules to the udev packages list
    services.udev.packages = [ cfg.package ];

    # gardendevd can read standard hwdb.bin under /etc/udev/hwdb.bin
    environment.etc."udev/hwdb.bin".source =
      pkgs.runCommand "gardendevd-hwdb.bin"
        {
          __structuredAttrs = true;
          preferLocalBuild = true;
          allowSubstitutes = false;
          packages = lib.unique config.services.udev.packages;
        }
        ''
          shopt -s nullglob

          mkdir -p root/etc/udev/hwdb.d
          for i in "''${packages[@]}"; do
            for j in "$i"/{etc,lib,var/lib}/udev/hwdb.d/*; do
              ln -s "$j" "root/etc/udev/hwdb.d/$(basename "$j")"
            done
          done

          ${package}/bin/gardendev-hwdb update --root "$PWD/root"
          mv root/etc/udev/hwdb.bin "$out"
        '';

    environment.etc."udev/rules.d".source =
      pkgs.runCommand "gardendevd-rules"
        {
          __structuredAttrs = true;
          preferLocalBuild = true;
          allowSubstitutes = false;
          packages = lib.unique config.services.udev.packages;
        }
        ''
          mkdir -p "$out"
          shopt -s nullglob

          for i in "''${packages[@]}"; do
            for j in "$i"/{etc,lib,var/lib}/udev/rules.d/*; do
              cat "$j" > "$out/$(basename "$j")"
            done
          done

          # gardendevd's own rules are authoritative on collision.
          for j in ${cfg.package}/lib/udev/rules.d/*; do
            cat "$j" > "$out/$(basename "$j")"
          done

          for i in "$out"/*.rules; do
            substituteInPlace "$i" \
              --replace-quiet \"/sbin/modprobe \"${pkgs.kmod}/bin/modprobe \
              --replace-quiet \"/sbin/mdadm \"${pkgs.mdadm}/sbin/mdadm \
              --replace-quiet \"/sbin/blkid \"${pkgs.util-linux}/sbin/blkid \
              --replace-quiet \"/bin/mount \"${pkgs.util-linux}/bin/mount \
              --replace-quiet /usr/bin/readlink ${lib.getExe' config.programs.coreutils.package "readlink"} \
              --replace-quiet /usr/bin/cat ${lib.getExe' config.programs.coreutils.package "cat"} \
              --replace-quiet /usr/bin/basename ${lib.getExe' config.programs.coreutils.package "basename"} 2>/dev/null
          done
        '';

    finit.services.gardendevd = {
      inherit (cfg) path;

      description = "device event daemon (gardendevd)";
      command = "${cfg.package}/bin/gardendevd -D %n " + lib.escapeShellArgs cfg.extraArgs;
      runlevels = "S12345789";
      cgroup.name = "init";
      notify = "s6";
      log = true;
    };

    finit.run =
      let
        defaults = {
          runlevels = "S";
          conditions = "service/gardendevd/ready";
          log = true;
          cgroup.name = "init";

          priority = 1;
        };
      in
      {
        "gardendevctl@1" = defaults // {
          description = "requesting device events";
          command = "${cfg.package}/bin/gardendevctl trigger -c add -t all";
        };
        "gardendevctl@2" = defaults // {
          description = "waiting for gardendevd to settle";
          command = "${cfg.package}/bin/gardendevctl settle -t 30";
        };
      };

    # TODO: share between device managers
    system.activation.scripts.gardendevd = lib.mkIf config.boot.kernel.enable {
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
  };
}
