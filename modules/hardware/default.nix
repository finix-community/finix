{
  config,
  pkgs,
  lib,
  ...
}:
let
  compressFirmware =
    firmware:
    let
      inherit (config.boot.kernelPackages) kernelAtLeast;
    in
    if !(firmware.compressFirmware or true) then
      firmware
    else if kernelAtLeast "5.19" then
      pkgs.compressFirmwareZstd firmware
    else if kernelAtLeast "5.3" then
      pkgs.compressFirmwareXz firmware
    else
      firmware;
in
{
  imports = [
    ./console.nix
    ./graphics.nix
    ./i2c.nix
    ./uinput.nix
    ./cpu/amd-ucode.nix
    ./cpu/intel-ucode.nix
    ./video/nvidia.nix
    ./video/nvidia-prime.nix
  ];

  options = {
    hardware.firmware = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = ''
        List of packages containing firmware files.  Such files
        will be loaded automatically if the kernel asks for them
        (i.e., when it has detected specific hardware that requires
        firmware to function).  If multiple packages contain firmware
        files with the same name, the first package in the list takes
        precedence.  Note that you must rebuild your system if you add
        files to any of these directories.
      '';
      apply =
        list:
        pkgs.buildEnv {
          name = "firmware";
          paths = map compressFirmware list;
          pathsToLink = [ "/lib/firmware" ];
          ignoreCollisions = true;
        };
    };
  };

  config.system.activation.scripts = lib.mkIf config.boot.kernel.enable {
    firmware.text = ''
      # Allow the kernel to find our firmware.
      if [ -e /sys/module/firmware_class/parameters/path ]; then
        echo -n "${config.hardware.firmware}/lib/firmware" > /sys/module/firmware_class/parameters/path
      fi
    '';

    disable-uevent-helper.text = ''
      if [ -e /proc/sys/kernel/hotplug ]; then
        echo "" > /proc/sys/kernel/hotplug
      fi
    '';
  };
}
