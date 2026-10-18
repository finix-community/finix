# Installation

This guide contains instructions for installing finix from the standard NixOS installation environment and tools, which is currently the recommended way of installing finix in lieu of a standalone installation environment.

finix can be installed and configured using any of channels, pinned inputs, or flakes.

## Acknowledgements

This guide is adapted from the excellent installation guides / configuration [examples](https://github.com/finix-community/examples) repository put together by [@xZecora](https://github.com/xZecora) (a.k.a. Vitrial).

Credits to [@vladbiber](https://github.com/vladbiber) for putting together the finix graphical installer.

## General Notes

- While this guide should be generally applicable to most systems, it is recommended to review the hardware in your system to make sure you install all needed drivers for networking or audio so you do not need to reboot into the NixOS live environment.
- Some users have reported errors from `efibootmgr` after running the `nixos-install` command. If the returned error code is 8, this can be ignored. It's caused by `efibootmgr` attempting to add non-existent boot entries to `limine`, which fails with return code 8. Existing boot entries are added without issue.
- If you run into any issues while following these instructions, feel free to open an issue on GitHub or join our [Discord](https://discord.gg/nVe5Zkaypg) server to ask for help.

## Prerequisites

An internet connection is required to complete this installation.

2GB of RAM and 32GB of available storage are recommended at minimum.

If you are looking to convert a pre-existing NixOS installation, it is highly recommended that you create a separate root partition for finix to work under.

## Graphical (Calamares) Installation

The graphical installer is a fork of `calamares-nixos-extensions`, and it runs underneath a NixOS live environment. You can grab a copy of the installer from the [GitHub repository](https://github.com/finix-community/installer) from the available download options. The README has instructions for building it from source if desired.

Any tool used to produce a bootable Linux USB disk from an ISO file will work, but this example will use `dd`. To create a bootable USB disk from the live iso, make sure your USB disk is unmounted, then run the following command. This will erase all data on the disk. 

```bash
sudo dd if=/path/to/installer.iso of=/dev/sdX bs=4M status=progress
```

Replace `/dev/sdX` with the name of your disk as it appears in the `/dev` directory. You can obtain a list of currently connected disks with `lsblk`. Make sure you use the non-numbered `sdX` name.

The command will run silently and provide a report once it finishes. Once it completes, you may safely remove your flash drive. 

Upon booting from the disk, the KDE Plasma desktop environment will start with no login required. The Calamares installer will start shortly afterwards. NetworkManager is brought up during the boot process, so ethernet should work with no additional configuration required. To configure wireless connections, open the the NetworkManager applet from the taskbar and connect to a wireless network. 

The installer will walk you through the following steps. 

1. The installer will first prompt you for your timezone, language, and preferred date time format. You may click anywhere in the presented map to select your timezone, or use the dropdown options below it.
2. Next, you will be prompted to select your preferred keyboard model, language, and layout. There is a text box provided for you to test your keyboard if needed.
3. You will then be prompted to configure a user account. The installer only configures a single user account. By default, secure passwords are enforced, but you may uncheck the box labeled "Require strong passwords." if you would like to bypass this requirement. The password you supply may also be applied to the root user account with the appropriately labeled checkbox.
4. The next menu presents you with a list of graphical sessions to install. You may click on one or more of the listed options to install them together. You may also select the "Minimal" option for no graphical session or greeter.
5. Next, you are prompted to choose which naming scheme to use for NixOS tooling commands, as well as the default directory your configuration resides in. Choose "Finix" to have your default configuration installed to `/etc/finix`, and to use `finix-rebuild` as your default rebuild command. Choose NixOS to have your default configuration installed in `/etc/nixos` and to use `nixos-rebuild` as your rebuild command.
6. The next menu allows you to enable an emergency access login shell in the event of a boot failure. This option is useful for acquiring debug logs and looking through the initial ram disk filesystem.
7. Next, you are presented with an option to allow unfree software packages.
8. Finally, you are presented with the disk partitioning menu. The ext4, xfs, btrfs, and f2fs filesystems are offered if you choose to fully erase the disk. 

Once you have partitioned your disks, you may proceed with the installation. The install process takes around 5 to 10 minutes, depending on the write speed of your target disk. 

## Manual Installation

If you have not already done so, grab a copy of the official NixOS installation media from this [link](https://nixos.org/download/#nixos-iso). It is recommended to download the graphical iso to reference these instructions. You will also need to copy long strings of text into your nix configuration files, notably a sha-512 password hash. 

Any tool to flash ISO files to a flash drive will work, but this example will use `dd`. To create a bootable USB disk from the live iso, make sure your USB disk is unmounted, then run the following command. 

```bash
sudo dd if=/path/to/installer.iso of=/dev/sdX bs=4M status=progress
```

Replace `/dev/sdX` with the name of your disk as it appears in the `/dev` directory. You can obtain a list of currently connected disks with `lsblk`. 

The command will run silently and provide a report of what it did once it finishes. Once it completes, you may safely remove your flash drive. 

Upon booting into the graphical environment, the KDE Plasma desktop environment will start with no login required. The Calamares installer program will start shortly thereafter, which you can now close. The installation process takes place entirely within a terminal, so go ahead and open one if you have not already. 

Upon booting into the minimal environment, you will drop directly into a TTY.

Type in `sudo -i` into your command prompt, as most if not all commands going forward require root level access.

### Networking

Both NixOS installation environments bring up NetworkManager by default during the boot process. Ethernet connections should work with no additional configuration required. To configure wireless connections in the graphical environment, open the the NetworkManager applet from the taskbar and connect to a wireless network. If you are installing from the minimal environment, you can use the NetworkManager TUI to configure wireless networks by running `nmtui`. To check that you are connected to a network, run `ip a`. 

### Partitioning disks

The NixOS minimal and graphical live environments have access to the usual CLI disk partitioning tools, including `fdisk`, `cfdisk`, `parted`, `gdisk`, and `cgdisk`. This example installation will use `parted`, but any of the others listed will work. It will fully erase the target disk and configure `ext4` as the primary filesystem. To determine the correct disk identifier in `/dev`, run `lsblk`. SSD drives are commonly prefixed with `/dev/nvme*`, while hard disk drives are prefixed with `/dev/sdX`, where X represents any arbitrary letter assigned to the drive.

#### Partitioning for UEFI systems

1. Execute the following to create a GPT partition table. You may ignore any warnings about updating entries in `/etc/fstab`.

```bash
parted /dev/sdX -- mklabel gpt
```

2. Create the root partition. This will leave 512MB in front for the EFI system partition, as well as space at the end of the block for an 8GB swap partition. Change `-8GB` to the size you need, or omit it entirely if no swap is desired.

```bash
parted /dev/sda -- mkpart root ext4 512MB -8GB
```

> [!NOTE]
> As a general rule of thumb, a swap partition should be roughly the same or double the size of your available system memory. 

3. Next, create the swap partition. 

```bash
parted /dev/sda -- mkpart swap linux-swap -8GB 100%
```

4. Finally, create the EFI system partition. NixOS uses this partition as the `/boot` drive.

```bash
parted /dev/sda -- mkpart ESP fat32 1MB 512MB
parted /dev/sda -- set 3 esp on
```

> [!NOTE]
> If you did not create a swap partition, use 3 instead of 2. Use `parted --list` to list all partition IDs if you are unsure of the correct one.

#### Partitioning for BIOS systems

1. Execute the following to create a MBR partition table. You may ignore any warnings about updating entries in `/etc/fstab`.

```bash
parted /dev/sdX -- mklabel msdos
```

2. Create the root partition. This will leave space at the end of the block for an 8GB swap partition. Change `-8GB` to the size you need, or omit it entirely if no swap is desired.

```bash
parted /dev/sda -- mkpart primary ext4 1MB -8GB
```

> [!NOTE]
> As a general rule of thumb, a swap partition should be roughly the same or double the size of your available system memory. 

3. Next, set the root partition's boot flag to on. This allows the disk to be booted from.

```bash
parted /dev/sda -- set 1 boot on
```

4. Finally, create the swap partition. 

```bash
parted /dev/sda -- mkpart primary linux-swap -8GB 100%
```

### Formatting

To initialize an `ext4` root partition without encryption, execute the following command. 

```bash
mkfs.ext4 -L finix /dev/sda1
```

To initialise a swap partition, execute the following.

```bash
mkswap -L swap /dev/sda2
```

For UEFI systems, execute the following to initialise an EFI system partition. `-n boot` will assign the `boot` label to it.

```bash
mkfs.fat -F 32 -n boot /dev/sda3
```

#### LUKS volumes

Finix supports encrypting partitions using LUKS. To create an encrypted volume and initialise an ext4 filesystem in it, run the following commands: 

```
cryptsetup luksFormat /dev/disk/by-uuid/... crypted

WARNING!
========
This will overwrite data on /dev/disk/by-uuid/... irrevocably.

Are you sure? (Type uppercase yes): YES
Enter LUKS passphrase: ***
Verify passphrase: ***

# decrypt the drive, map to /dev/mapper/crypted
cryptsetup luksOpen /dev/disk/by-uuid/... crypted

# format the decrypted drive under mapper to ext4 
mkfs.ext4 -L finix /dev/mapper/crypted
```

### Mounting disks

To mount your root partition, run the following.

```bash
mount /dev/disk/by-label/finix /mnt
```

UEFI systems: To mount your EFI system partition, run the following.

```bash
mkdir -p /mnt/boot
mount -o umask=077 /dev/disk/by-label/boot /mnt/boot
```

If your system has a limited amount of memory, you may want to activate your swap partition now, as the system build process may require a lot of memory depending on your configuration.

```bash
swapon /dev/sda2
```

### Configuration

Once you have mounted all of your drives, run the command `mkdir -p /mnt/etc/nixos` to create the directory we will work in, and run `cd /mnt/etc/nixos` to enter it.

You may now generate your starter `hardware-configuration.nix` file with the following command:

```bash
nixos-generate-config --root /mnt --show-hardware-config > ./hardware-configuration.nix
```

Open the generated file with your editor and delete the `imports = [ ... ];` statement at the beginning, keeping all of the `boot` options for kernel modules, and removing every option below the `fileSystems` and `swapDevices` options. If you need an example for what this file will look like after the specified modifications, see below. Do NOT copy this file directly, as the listed filesystem configuration will fail to evaluate.


```nix
# hardware-configuration.nix
{
  config,
  lib,
  pkgs,
  ...
}:

{
  boot.initrd.availableKernelModules = [
    "ahci"
    "xhci_pci"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  # WARN: If you don't set this, you potentially won't be able to boot your machine.
  hardware.firmware = [ pkgs.linux-firmware ];

  # TODO: Replace this with your actual filesystem layout.
  fileSystems = {
    "/" = {
      device = "/dev/sda2";
      fsType = "ext4";
    };

    "/boot" = {
      device = "/dev/sda1";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };
  };

  swapDevices = [ ];
}
```

If you would like to enable automatic updates to CPU microcode, add or keep the following options at the bottom of your hardware config:

```nix
hardware.cpu.amd.updateMicrocode = true; # for amd CPUs
hardware.cpu.intel.updateMicrocode = true; # for amd CPUs
```

It is generally recommended to add the following line to `hardware-configuration.nix` to ensure you have the necessary firmware you need for your system.

```nix
hardware.firmware = [ pkgs.linux-firmware ];
```

If you are installing finix into a QEMU-based virtual machine, you will need to keep or re-add the following statement in your hardware configuration:

```nix
{
  config,
  lib,
  pkgs,
  modulesPath, # keep or re-add this
  ...
}:
{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];
  
  # rest of configuration
}
```

Since modulesPath does not exist by default in finix, you will need to add the following to your flake.nix inside finix.lib.finixSystem to expose it (or system.nix if you are using channels):

```nix
finix.lib.finixSystem {
  inherit (pkgs) lib;
  specialArgs = {
    modulesPath = toString nixpkgs + "/nixos/modules";
    inherit inputs;
  };
};
```

If you are installing onto a BIOS system, you will need to add the following Limine settings to your configuration.

```nix
programs.limine.biosSupport = true;
```

To denote the BIOS device to install to, set the following option:

```nix
programs.limine.biosDevice = "/dev/sda";
```

The specified device must be a whole disk name.

#### Note about LUKS devices

Finix does not ship the `boot.initrd.luks.devices` option set, so you will need to manually add entries for the encrypted volume and its respective mapped name in `/dev/mapper`. Here is an example configuration:

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

### Configuring Flakes or Channels

Run `mkdir -p /mnt/etc/finix` to create a finix directory under `/mnt/etc`, and `cd` into it. The next few steps will differ if you plan to configure finix with a flake-based or channel-based workflow, so go ahead and skip to the appropriate section. You cannot configure both flakes and channels at the same time -- you can only configure one or the other. Flakes are the generally recommended method for pinning nix dependencies.

#### Flakes

The `finix-community/examples` repository contains starter configuration files you can obtain with the following commands:

```bash
# minimal flake
nix --extra-experimental-features 'nix-command flakes' flake init -t github:finix-community/examples#installation-minimal
nix --extra-experimental-features 'nix-command flakes' flake update


# graphical flake
nix --extra-experimental-features 'nix-command flakes' flake init -t github:finix-community/examples#installation-graphical
nix --extra-experimental-features 'nix-command flakes' flake update
```

Both flakes will pull from the latest commit on the `main` branch of finix. The **minimal flake** configures everything needed for a minimal TTY based environment. It contains an example `hardware-configuration.nix` that is compatible with `finix's` existing hardware configuration options. The **graphical flake** comes pre-configured with the `labwc` Wayland compositor and the `tuigreet` greeter. No extra configuration for `labwc` or `tuigreet` is provided. Both setups configure networking by enabling `dhcpcd` (wired) and `iwd` (wireless).

Edit your `flake.nix` to the following:

```
nixosConfigurations.finixos -> nixosConfigurations.<desired profile name>
```

#### Channels

The `finix-community/examples` repository contains starter configuration files you can copy to use as a base for your configuration. To acquire them, run the following command:

```bash
nix --enable-experimental-features 'nix-command flakes' flake init -t github:finix-community/examples#installation-channels
```

The cloned files configure everything required to boot into a TTY environment with network access using `dhcpcd` and `iwd`.

Run these three commands to add the channels you will need:

```bash
nix-channel --add https://channels.nixos.org/nixos-unstable nixos
nix-channel --add https://github.com/finix-community/finix/archive/refs/heads/main.tar.gz finix
nix-channel --update
```

If you are installing finix into a QEMU-based virtual machine, you will need to keep or re-add the following statement in your hardware configuration:

```nix
imports = [
  (modulesPath + "/profiles/qemu-guest.nix")
];
```

Since modulesPath does not exist by default in finix, you will need to add the following to your flake.nix inside finix.lib.finixSystem to expose it (or system.nix if you are using channels):

```nix
finix.lib.finixSystem {
  inherit (pkgs) lib;
  specialArgs = {
    modulesPath = toString nixpkgs + "/nixos/modules";
    inherit inputs;
  };
};
```

### Configuring

Copy the contents of your edited `/mnt/etc/nixos/hardware-configuration.nix` into the hardware configuration file you cloned from the examples repository.

You can now edit `configuration.nix` to your liking. The default configuration comes preset with options for network setup, preferred editors, and sudo/doas. Refer to our [options search](https://finix-community.github.io/finix/options.html) for a comprehensive list of configuration modules, or our [configuration guide](https://finix-community.github.io/finix/finix-vs-nixos.html) for a more simplified overview of common options. You will need to add any wanted modules into the top level `imports` statement in order for them to be included at evaluation time.

It is generally recommended to add the `shadow` package into your packages list, if it is not there already. Some users have reported an issue where the root user password prompt does not appear at install time without this package. You may remove it after installation as it is enabled by default.

Lastly for configuration, customize the `user.user.<USERNAME>` entry to match your preferences. `<USERNAME>` should be changed to your username, and `password` is a `sha-512` hash of your password if you choose to configure it delaratively instead of using `passwd`. This hash can be generated with:

```bash
mkpasswd -m sha-512 '<password>'
```

where `<password>` is your desired password. Once you complete installation, you will need to delete this password hash if you choose to reset your password using `passwd`. While it is *generally* safe to store password hashes like this, it is recommended to incorporate a secrets manager like [`sops`](https://github.com/getsops/sops) into your configuration to manage passwords instead. Instructions on how to do so are beyond the scope of this guide. Feel free to check out [aanderse's configuration](https://github.com/aanderse/finix-config) for an example implementation.

### Installing

Now that everything has been configured, we can run the necessary commands to begin installing.

**Flake-based install command**

```bash
nixos-install --root /mnt --flake /path/to/flake/directory#<desired profile name>
```

> [!NOTE]
> If you get an error when running `nixos-install` regarding a mismatched hash, run it a second time and it should go through.

**Channel-based install command**

```bash
nixos-install --root /mnt --file /mnt/etc/finix/system.nix --channel /nix/var/nix/profiles/per-user/root/channels
```

Once installation has completed, reboot your system and remove the flash drive with the NixOS live environment. Welcome to finix!

## Post installation notes

It is recommended to copy your configuration files into your home folder so you do not need root privileges to edit them. An example set of commands to use might be: 

```bash
cp /etc/finix ~/.config/finix

# root is the owner of those files, so we need to chown them
sudo chown username:users ~/.config/finix -r
```

For more information on configuring your system, see [Configuring](./configuring.md).
