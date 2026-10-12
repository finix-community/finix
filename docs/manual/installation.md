# Installation

This guide contains instructions for installing finix from the standard NixOS installation environment and tools, which is currently the recommended way of installing finix in lieu of a standalone installation environment.

finix can be installed and configured using any of channels, pinned inputs, or flakes.

## Acknowledgements

This guide is adapted from the excellent installation guides / configuration [examples](https://github.com/finix-community/examples) repository put together by [@xZecora](https://github.com/xZecora) (a.k.a. Vitrial).

## General Notes

- While this guide should be generally applicable to most systems, it is recommended to review the hardware in your system to make sure you install all needed drivers for networking or audio so you do not need to reboot into the NixOS live environment.
- Some users have reported errors from `efibootmgr` after running the `nixos-install` command. If the returned error code is 8, this can be ignored. It's caused by `efibootmgr` attempting to add non-existent boot entries to `limine`, which fails with return code 8. Existing boot entries are added without issue.
- If you run into any issues while following these instructions, feel free to open an issue on GitHub or join our [Discord](https://discord.gg/nVe5Zkaypg) server to reach out.

## Prerequisites

If you have not already done so, grab a copy of the official NixOS installation media from this [link](https://nixos.org/download/#nixos-iso). It is recommended to download the graphical iso to reference these instructions. You will also need to copy long strings of text into your nix configuration files, notably a sha-512 password hash. 

An internet connection is required to complete this installation.

2GB of RAM and 32GB of available storage are recommended at minimum.

If you are looking to convert a pre-existing NixOS installation, it is highly recommended that you create a separate root partition for finix to work under.

## Process

The installation process takes place entirely within a terminal, so go ahead and open one if you have not already. Type in `sudo -i` into your command prompt, as most if not all commands going forward require root level access.

Follow the instructions from [this guide](https://nixos.wiki/wiki/NixOS_Installation_Guide) up until the "Create NixOS config" section. This is the point where the NixOS and finix installation procedures diverge.

Once you have mounted all of your drives, run the command `mkdir -p /mnt/etc/nixos` to create the directory we will work in, and run `cd /mnt/etc/nixos` to enter it.

You may now generate your starter `hardware-configuration.nix` file with the following command:

```bash
nixos-generate-config --root /mnt --show-hardware-config > ./hardware-configuration.nix
```

Open the generated file with your editor and delete the `imports = [ ... ];` statement at the beginning, keeping all of the `boot` options for kernel modules, and removing every option below the `fileSystems` and `swapDevices` options. If you need an example for what this file will look like after the specified modifications, see this [example](https://github.com/finix-community/examples/installations/channels/hardware-configuration.nix). Do NOT copy this file directly, as the listed filesystem configuration will fail to evaluate.

If you would like to enable automatic updates to CPU microcode, add or keep the following options at the bottom of your hardware config:

```nix
hardware.cpu.amd.updateMicrocode = true; # for amd CPUs
hardware.cpu.intel.updateMicrocode = true; # for amd CPUs
```

It is generally recommended to add the following line to `hardware-configuration.nix` to ensure you have the necessary firmware you need for your system.

```nix
hardware.firmware = [ pkgs.linux-firmware ];
```

Run `mkdir -p /mnt/etc/finix` to create a finix directory under `/mnt/etc`, and `cd` into it. The next few steps will differ if you plan to configure finix with a flake-based or channel-based workflow, so go ahead and skip to the appropriate section.

### Configuring Flakes

The `finix-community/examples` repository contains starter configuration files you can obtain with the following commands:

```bash
# minimal flake
nix --extra-experimental-features 'nix-command flakes' flake init -t github:finix-community/examples#installation-minimal

# graphical flake
nix --extra-experimental-features 'nix-command flakes' flake init -t github:finix-community/examples#installation-graphical
```

The **minimal flake** configures everything needed for a minimal TTY based environment. It contains an example `hardware-configuration.nix` that is compatible with `finix's` existing hardware configuration options. The **graphical flake** comes pre-configured with the `labwc` Wayland compositor and the `tuigreet` greeter. No extra configuration for `labwc` or `tuigreet` is provided. Both setups configure networking by enabling `dhcpcd` (wired) and `iwd` (wireless).

Edit your `flake.nix` to the following:

```
nixosConfigurations.finixos -> nixosConfigurations.<desired profile name>
```

### Configuring Channels

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

### Making Needed Changes

Copy the contents of your edited `/mnt/etc/nixos/hardware-configuration.nix` into the hardware configuration file you cloned from the examples repository.

You can now edit `configuration.nix` to your liking. The default configuration comes preset with options for network setup, preferred editors, and sudo/doas. Refer to our [options search](https://finix-community.github.io/finix/options.html) for a comprehensive list of configuration modules, or our [configuration guide](https://finix-community.github.io/finix/finix-vs-nixos.html) for a more simplified overview of common options. You will need to add any wanted modules into the top level `imports` statement in order for them to be included at evaluation time.

It is generally recommended to add the `shadow` package into your packages list, if it is not there already. Some users have reported not receiving a prompt to set the root password at install time without this package. 

Lastly for configuration, customize the `user.user.<USERNAME>` entry to match your preferences. `<USERNAME>` should be changed to your username, and `password` is a `sha-512` hash of your password if you choose to configure it delaratively instead of using `passwd`. This hash can be generated with:

```bash
mkpasswd -m sha-512 '<password>'
```

where `<password>` is your desired password. Once you complete installation, you will want to delete this password hash if you reset your password using `passwd`. While it is *generally* safe to store password hashes like this, it is recommended to incorporate a secrets manager like [`sops`](https://github.com/getsops/sops) into your configuration to manage passwords instead. Instructions on how to do so are beyond the scope of this guide. Feel free to check out [aanderse's configuration](https://github.com/aanderse/finix-config) for an example implementation.

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
