{ config, pkgs, lib, ... }:
let
  cfg = config.programs.virtualbox;

  devVBoxScript = pkgs.execline.writeScript "mdevd-vbox.el" "" ''
    # Usage: mdevd-vbox-usb.sh add|remove MAJOR MINOR SYSFS_PATH

    importas -u ACTION 1
    importas -u MAJOR 2
    importas -u MINOR 3
    importas -u SYSFS 4

    ifelse { test "$ACTION" = "add" } {
      redirfd -r 0 ''${SYSFS}/bDeviceClass
      importas -i CLASS 0
      exec ${cfg.package}/libexec/virtualbox/VBoxCreateUSBNode.sh $MAJOR $MINOR $CLASS
    } {
      exec ${cfg.package}/libexec/virtualbox/VBoxCreateUSBNode.sh --remove $MAJOR $MINOR
    }
  '';
in
{
  options.programs.virtualbox = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [virtualbox](${pkgs.virtualbox.meta.homepage}).

        ::: {.note}
        In order to pass USB devices from the host to guests, a user
        needs to be added to the `vboxusers` group.
        :::
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.virtualbox;
      defaultText = lib.literalExpression "pkgs.virtualbox";
      description = ''
        The package to use for `virtualbox`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelModules = [
      "vboxdrv"
      "vboxnetadp"
      "vboxnetflt"
    ];

    boot.extraModulePackages = [
      (config.boot.kernelPackages.virtualbox.override { virtualbox = cfg.package; })
    ];

    environment.systemPackages = [ cfg.package ];

    services.mdevd.hotplugRules = lib.mkMerge [
      # fallthrough rules at the top
      (lib.mkBefore ''
        -SUBSYSTEM=usb;DEVTYPE=usb_device;.* root:root 0600 +${devVBoxScript} add $MAJOR $MINOR /sys$DEVPATH
        -SUBSYSTEM=usb;DEVTYPE=usb_device;.* root:root 0600 -${devVBoxScript} remove $MAJOR $MINOR /sys$DEVPATH
      '')

      ''
        vboxdrv     root:vboxusers 0660
        vboxdrvu    root:root 0666
        vboxnetctl  root:vboxusers 0660
      ''
    ];

    services.udev.packages = [
      (pkgs.writeTextDir "/etc/udev/rules.d/virtualbox.rules" ''
        SUBSYSTEM=="usb_device", ACTION=="add", RUN+="${cfg.package}/libexec/virtualbox/VBoxCreateUSBNode.sh $major $minor $attr{bDeviceClass}"
        SUBSYSTEM=="usb", ACTION=="add", ENV{DEVTYPE}=="usb_device", RUN+="${cfg.package}/libexec/virtualbox/VBoxCreateUSBNode.sh $major $minor $attr{bDeviceClass}"
        SUBSYSTEM=="usb_device", ACTION=="remove", RUN+="${cfg.package}/libexec/virtualbox/VBoxCreateUSBNode.sh --remove $major $minor"
        SUBSYSTEM=="usb", ACTION=="remove", ENV{DEVTYPE}=="usb_device", RUN+="${cfg.package}/libexec/virtualbox/VBoxCreateUSBNode.sh --remove $major $minor"

        KERNEL=="vboxdrv",    OWNER="root", GROUP="vboxusers", MODE="0660", TAG+="systemd"
        KERNEL=="vboxdrvu",   OWNER="root", GROUP="root",      MODE="0666", TAG+="systemd"
        KERNEL=="vboxnetctl", OWNER="root", GROUP="vboxusers", MODE="0660", TAG+="systemd"
      '')
    ];

    users.groups = {
      vboxusers.gid = config.ids.gids.vboxusers;
    };
  };
}
