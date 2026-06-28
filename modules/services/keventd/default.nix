{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.services.keventd;
in
{
  options.services.keventd = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [keventd](${pkgs.finit.meta.homepage}) as a system service.
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
        Additional arguments to pass to `keventd`.
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
    assertions = [
      {
        assertion = lib.versionAtLeast config.finit.package.version "5.0";
        message = "finit version must be at least 5.0";
      }
    ];

    services.keventd.extraArgs = [
      "-c"
      (if cfg.debug then "-d" else "-n")
    ];

    services.keventd.path = [
      config.programs.coreutils.package
      pkgs.gnugrep
      pkgs.gnused
      pkgs.kmod
      pkgs.util-linux
    ];

    # contribute finit's bundled rules to the udev packages list.
    services.udev.packages = [ config.finit.package ];

    environment.etc."udev/rules.d".source =
      pkgs.runCommand "keventd-rules"
        {
          __structuredAttrs = true;
          preferLocalBuild = true;
          allowSubstitutes = false;
          packages = lib.unique config.services.udev.packages;
        }
        ''
          mkdir -p $out
          shopt -s nullglob

          for i in "''${packages[@]}"; do
            echo "Adding rules for package $i"
            for j in $i/{etc,lib,var/lib}/udev/rules.d/*; do
              echo "Copying $j to $out/$(basename $j)"
              cat $j > $out/$(basename $j)
            done
          done

          for i in $out/*.rules; do
            substituteInPlace $i \
              --replace-quiet \"/sbin/modprobe \"${pkgs.kmod}/bin/modprobe \
              --replace-quiet \"/sbin/mdadm \"${pkgs.mdadm}/sbin/mdadm \
              --replace-quiet \"/sbin/blkid \"${pkgs.util-linux}/sbin/blkid \
              --replace-quiet \"/bin/mount \"${pkgs.util-linux}/bin/mount \
              --replace-quiet /usr/bin/readlink ${lib.getExe' config.programs.coreutils.package "readlink"} \
              --replace-quiet /usr/bin/cat ${lib.getExe' config.programs.coreutils.package "cat"} \
              --replace-quiet /usr/bin/basename ${lib.getExe' config.programs.coreutils.package "basename"} 2>/dev/null
          done
        '';

    finit.services.keventd = {
      inherit (cfg) path;

      description = "device event daemon (keventd)";
      command = "${config.finit.package}/libexec/finit/keventd " + lib.escapeShellArgs cfg.extraArgs;
      runlevels = "S12345789";
      cgroup.name = "init";
      notify = "pid";
      log = true;
    };

    # TODO: add finit.services.reloadTriggers option
    environment.etc."finit.d/keventd.conf".text = lib.mkAfter ''

      # reload trigger
      # ${config.environment.etc."udev/rules.d".source}
    '';

    # TODO: share between device managers
    system.activation.scripts.keventd = lib.mkIf config.boot.kernel.enable {
      text = ''
        # Allow the kernel to find our firmware.
        if [ -e /sys/module/firmware_class/parameters/path ]; then
          echo -n "${config.hardware.firmware}/lib/firmware" > /sys/module/firmware_class/parameters/path
        fi
      '';
    };

    system.switch.inhibitors.device-manager = "keventd";
  };
}
