{ config, pkgs, lib, ... }:
let
  cfg = config.hardware.i2c;
in
{
  options.hardware.i2c = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable support for `i2c` devices. Access to these devices is granted
        to users in the {option}`hardware.i2c.group` group.
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "i2c";
      description = ''
        Group to own the `/dev/i2c-*` devices.

        ::: {.note}
        If you want non-`root` users to be able to access these `i2c` devices, add
        them to this group.
        :::

        ::: {.note}
        If left as the default value this group will automatically be created
        on system activation, otherwise you are responsible for
        ensuring the group exists before system activation has completed.
        :::
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelModules = [ "i2c-dev" ];

    users.groups = lib.mkIf (cfg.group == "i2c") {
      i2c = { };
    };

    services.mdevd.hotplugRules = ''
      i2c-[0-9]*  root:${cfg.group} 660
    '';

    services.udev.packages = lib.singleton (
      pkgs.writeTextFile {
        name = "i2c-udev-rules";
        text = ''
          # allow group ${cfg.group} and users with a seat use of i2c devices
          ACTION=="add", KERNEL=="i2c-[0-9]*", TAG+="uaccess", GROUP="${cfg.group}", MODE="660"
        '';
        destination = "/etc/udev/rules.d/70-i2c.rules";
      }
    );
  };
}
