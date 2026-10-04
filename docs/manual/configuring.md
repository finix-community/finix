# Configuring

This page serves as a high level overview for configuring a finix system.

> [!NOTE]
> This page is a stub. If you have something you would like to contribute, feel free to open a PR and add any documentation for configuring services, programs, or low level system components.

## Core system components

### Bootloaders

#### limine

Finix currently ships [limine](https://github.com/Limine-Bootloader/Limine) as the only available bootloader program. It can be installed on BIOS and UEFI systems, with support for x86-64, aarch64, and riscv64 architectures. It supports both MBR and GPT paritioning schemes, as well as the FAT12/16/32 and ISO9660 filesystems. It may also be configured to support secure boot with [`sbctl`](https://github.com/Foxboron/sbctl).

This program is not imported by default. To enable it, add the following to your configuration:

```nix
{ config, modules, ... }:
{
  imports = [ modules.limine ];
  programs.limine.enable = true;
}
```

**Limiting the number of generations**

To limit the maximum amount of generations limine keeps in your boot partition, set the following option:

```nix
programs.limine.maxGenerations = 10;
```

**Adding additional entries**

To add additional bootable entries to limine, you will need to specify the following items in limine's configuration syntax:

- boot protocol
- location of executable or kernel
- name of entry

Here is an example of adding an entry for the GRUB bootloader located on a separate disk drive.

```nix
programs.limine.extraEntries = ''
  /+Arch Linux
    //GRUB: Arch Linux
      protocol: efi
      path: uuid(...):/EFI/grub/grubx64.efi
'';
```

You can obtain the UUID for the desired disk partition with `lsblk -f`. If the normal UUID does not work, try the disk's PARTUUID obtained from `blkid`. See [upstream documentation](https://github.com/Limine-Bootloader/Limine/blob/v12.x/CONFIG.md) for more details.

**Configuring secure boot**

To enable limine's secure boot support, enable the configuration option. 

```nix
programs.limine.secureBoot.enable = true;
```

Enabling this option will still require pre-generated secure boot keys. The limine module has configuration options under the `secureBoot` option set you can use to automate this process:

- `autoEnrollKeys.enable`: Enrolls automatically generated secure boot keys. 
- `autoEnrollKeys.extraArgs`: Extra arguments to pass to the `sbctl` executable. Defaults to `--microsoft` and `--firmware-builtin` to automatically add secure boot keys signed by Microsoft and builtin device firmware.
- `autoGenerateKeys`: Enable generating keys automatically when none exist during bootloader installation.

**Wallpapers**

Limine supports adding custom wallpapers to be shown in the background of the boot menu. To add a wallpaper, add the following line:

```nix
programs.limine.settings.wallpaper = [ pkgs.nixos-artwork.wallpapers.simple-dark-gray-bootloader.gnomeFilePath ];
```

If more than one wallpaper is listed, a random one will be chosen during boot.

See the options search for a full list of limine's configuration options.

#### Custom boot script

Finix exposes `boot.loader.script`, an option for adding a custom script for installing any bootloader not shipped by finix. See the module for [efistubmgr](https://github.com/FixeQD/efistubmgr) in [community-modules](https://github.com/finix-community/community-modules/blob/main/modules/programs/efistubmgr/default.nix) for a reference implementation.

### Filesystems

Finix's filesystem configuration syntax is nearly the same as NixOS. The following filesystems are currently supported:

- 9p
- btrfs
- ext2
- ext4
- f2fs
- fuse
- iso9660
- LUKS
- LVM
- ntfs3
- squashfs
- tmpfs
- vfat
- xfs
- zfs

Support for each filesystem configuration is automatically enabled in both the initial ramdisk and a live system when the `fsType` option is specified. 

#### Note about encrypted LUKS volumes

Finix does not support the `boot.initrd.luks.devices` option set as of yet, so you will need to manually add entries for the encrypted volume and its respective mapped name in `/dev/mapper`. Here is an example configuration:

```nix
fileSystems."/" = {
  device = "/dev/mapper/crypted";
  fsType = "ext4";
};

fileSystems."crypted" = {
  device = "/dev/disk/by-uuid/...";
  fsType = "luks";
  neededForBoot = true;
  options = [ "--debug" ];
};
```

> [!NOTE]
> There is a reported [issue](https://github.com/finix-community/finix/issues/216) preventing `cryptsetup` from opening the declared device if a user has no declared `options` attribute. As a workaround, set it to `[ "--debug"]` to enable debug logging. This will clutter your console output in the initial ram disk but it will allow `cryptsetup` to open the correct device. 

If you have a swap partition encrypted with LUKS, you will need to declare it as a LUKS device and add the appropriate mapping to the list of `swapDevices`. Here is an example configuration:

```nix
fileSystems."crypted-swap" = {
  device = "/dev/disk/by-uuid/...";
  fsType = "luks";
  neededForBoot = true;
  options = [ "--debug" ];
};

swapDevices = [
  { device = "/dev/mapper/crypted-swap"; }
];
```

### Device managers

Finix currently ships four userspace device managers, which are the programs responsible for handling kernel events as well as populating the `/dev` directory with input devices, storage devices, rendering devices, and more. None are enabled by default. The following is a list of device managers supported by finix and the level of hardware compatibility a user can expect from each one.

#### eudev

[eudev](https://github.com/eudev-project/eudev) is a fork of systemd with the aim of isolating the device manager from the rest of systemd. It has the broadest compatibility with any given hardware, given the ubiquity of systemd-udev in the Linux ecosystem. It is capable of reading udev-style device rules and requires no tinkering to reach feature parity with systemd-udev. Any prewritten udev rules installed by Nix packages will work without issue.

This service is imported by default. To enable it, add the following line to your system configuration:  

```nix
services.udev.enable = true;
```

Some software packages may ship prewritten udev rules as a runtime dependency. To add these udev rules to `/etc/udev/rules.d`, add the following line to your configuration:

```nix
services.udev.packages = [ pkgs.libtmp.out ];
```

#### gardendevd

[gardendevd](https://codeberg.org/Gardenhouse/gardendevd) is a device manager designed to be a lightweight replacement to systemd-udev. It is able to read and parse udev-style device rules to populate device nodes. It optionally runs on top of mdevd, another more lightweight device manager, but it is runable as a standalone daemon. Some programs may require recompilation with [libudev-garden](https://codeberg.org/Gardenhouse/libudev-garden), a fork of libudev-zero written to be used with gardendevd. Issues have been reported regarding the reliability of services written to be tighly integrated with systemd-udev -- particularly gvfs and udisks2. It is possible that users will need to write custom udev rules to support any uncommon hardware not covered by the stock rules shipped by gardendevd.

This service is imported by default. To enable it, add the following line to your system configuration:  

```nix
services.gardendevd.enable = true;
```

Optionally, you may also enable mdevd to run under gardendevd.  

Software packages that ship udev rules can be installed and read by gardendevd with the following:

```nix
services.udev.packages = [ pkgs.libtmp.out ];
```

`services.udev` does not need to be enabled for this option to work.

#### keventd

[keventd](https://troglobit.com/projects/finit/) is the device manager bundled with finit since version 5 and up. It is capable as a lightweight replacement to systemd-udev in tandem with libudev-zero, as it is able to read udev style rules. It is not as feature complete as gardendevd at the time of writing, and some programs and services will need to be recompiled with libudev-zero in place of libudev in order for them to function properly with keventd. Issues have been reported regarding the reliability of services that are tighly integrated with systemd-udev -- notably gvfs and udisks2, and it is possible that end users will need to write custom udev rules to support any uncommon hardware not covered by the stock rules shipped by keventd.

This service is imported by default. To enable it, add the following line to your system configuration:  

```nix
services.keventd.enable = true;
```

Software packages that ship udev rules can be installed and read by keventd with the following:

```nix
services.udev.packages = [ pkgs.libtmp.out ];
```

`services.udev` does not need to be enabled for this option to apply.

#### mdevd

[mdevd](https://skarnet.org/software/mdevd/) is a lightweight device manager from the Skarnet/s6 family of Linux system utilities. It is designed to be a drop in replacement to the mdev device manager included in the BusyBox software suite. It is by far the leanest of the other three services listed, and it has the narrowest hardware compatibility. It is ideal for systems with limited resources or those with little need for broad hardware support beyond standard input and storage devices. Programs and services dealing with low level input, notably pipewire and most graphical environments, will require recompilation with libudev-zero in order to function properly. gvfs and udisks2 will not work with this device manager. If any additional hardware support is desired, a user will need to write custom rules utilising mdevd syntax, which is wholly unique to udev syntax. Examples for what these rules look like may be found [here](https://git.lin.moe/aports/lin/mdev-helper/mdev.conf.html).

This service is imported by default. To enable it, add the following line to your system configuration:  

```nix
services.mdevd.enable = true;
```

You may supply additional device rules with the following options:

```nix
services.mdevd.coldplugRules = '''';
services.mdevd.hotplugRules = '''';
```

It is generally advised when running this device manager to set the value of `services.mdevd.nlgroups = 4` in order to rebroadcast kernel events to libudev-zero.

### getty

getty is a program that manages login terminals. Finit ships with a built in getty implementation which is used by default when the getty service is enabled.

This service is not imported by default. To import and enable it, add the following to your system configuration:  

```nix
{ config, modules, ... }:
{
  imports = [ modules.getty ];
  services.getty.enable = true;
}
```

You may also switch your preferred getty implementation using the option `services.getty.package`, like so:

```nix
services.getty.package = pkgs.util-linux // { mainProgram = "agetty"; };
```

### Shells

TODO

### Networking

TODO

### System time

TODO

timezone setup, ntp daemon setup

## User sessions

This section contains information regarding user session management. 

### Session managers

TODO

`sessiond`, `seatd`, `elogind`

### Setting environment variables

`security.pam.environment` method and `environment.variables` method of setting env vars

## Graphical environments

This section contains information relating setting up and using graphical environments.

### Login managers

TODO

### Wayland compositors

TODO

- `labwc`
- `niri`
- `hyprland`
- `sway`

etc.

### Xorg

TODO

- `vxwm`
- `openbox`

etc.

### Desktop environments

TODO

- `lxqt`
- `cosmic-de`

etc.

### Audio

TODO

`pipewire` mostly

## Server software

### Databases

TODO

postgresql, mariadb

### Docker

TODO

no rootless support

### Schedulers

TODO

`providers.scheduler`
