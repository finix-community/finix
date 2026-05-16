{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.hardware.uinput;
in
{
  options.hardware.uinput = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [uinput](https://kernel.org/doc/html/latest/input/uinput.html) support.
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "uinput";
      description = ''
        Group to own the `uinput` devices.

        ::: {.note}
        If you want non-`root` users to be able to access these `uinput` devices, add
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
    boot.kernelModules = [ "uinput" ];

    services.udev.packages = lib.singleton (
      pkgs.writeTextFile {
        name = "uinput-udev-rules";
        text = ''
          SUBSYSTEM=="misc", KERNEL=="uinput", MODE="0660", GROUP="${cfg.group}", OPTIONS+="static_node=uinput"
        '';
        destination = "/etc/udev/rules.d/70-uinput.rules";
      }
    );

    services.mdevd.hotplugRules = lib.mkBefore ''
      -SUBSYSTEM=misc;uinput root:${cfg.group} 0660
    '';

    users.groups = lib.optionalAttrs (cfg.group == "uinput") {
      uinput = { };
    };
  };
}
