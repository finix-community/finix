# Configuring

This page serves as a high level overview for configuring a `finix` system.

> [!NOTE]
> This page is a stub. If you have something you would like to contribute, feel free to open a PR and add any documentation for configuring services, programs, or low level system components.

## Core system components

### Bootloaders

TODO

`limine`

### Filesystems

TODO

### Device managers

`finix` currently ships four userspace device managers, which are the programs responsible for handling kernel events as well as populating the `/dev` directory with input devices, storage devices, rendering devices, and more. None are enabled by default. The following is a list of device managers supported by `finix` and the level of hardware compatibility a user can expect from each one.

#### `eudev`

[`eudev`](https://github.com/eudev-project/eudev) is a fork of `systemd` with the aim of isolating the device manager from the rest of `systemd`. It has the broadest compatibility with any given hardware, given the ubiquity of `systemd-udev` in the Linux ecosystem. It is capable of reading `udev` style device rules and requires no tinkering to reach feature parity with `systemd-udev`. Any prewritten `udev` rules installed by `nix` packages will work without issue.

This service is imported by default. To enable it, add the following line to your system configuration:  

```nix
services.udev.enable = true;
```

Some software packages may ship prewritten `udev` rules as a runtime dependency. To add these udev rules to `/etc/udev/rules.d`, add the following line to your configuration:

```nix
services.udev.packages = [ pkgs.libtmp.out ];
```

#### `gardendevd`

[`gardendevd`](https://codeberg.org/Gardenhouse/gardendevd) is a device manager designed to be a lightweight replacement to `systemd-udev`. It is able to read and parse `udev` style device rules to populate device nodes. It optionally runs on top of `mdevd`, another lightweight userspace device manager, but it is runable as a standalone daemon. Some programs may require recompilation with [`libudev-garden`](https://codeberg.org/Gardenhouse/libudev-garden), a fork of `libudev-zero` and a substitution to the ubiquitus `libudev` written to be used with `gardendevd`. Issues have been reported regarding the reliability of services written to be tighly integrated with `systemd-udev` -- particularly `gvfs` and `udisks2`. It is possible that users will need to write custom `udev` rules to support any uncommon hardware not covered by the stock rules shipped by `gardendevd`.

This service is imported by default. To enable it, add the following line to your system configuration:  

```nix
services.gardendevd.enable = true;
```

Optionally, you may also enable `mdevd` to run above `gardendevd`.  

Software packages that ship `udev` rules can be installed and read by `gardendevd` with the following:

```nix
services.udev.packages = [ pkgs.libtmp.out ];
```

`services.udev` does not need to be enabled for this option to work.

#### `keventd`

[`keventd`](https://troglobit.com/projects/finit/) is the device manager bundled with `finit` since version 5 and up. It is capable as a lightweight replacement to `systemd-udev` in tandem with `libudev-zero`, as it is able to read `udev` style rules. It is not as feature complete as `gardendevd` at the time of writing, and some programs and services will need to be recompiled with `libudev-zero` in place of `libudev` in order for them to function properly with `keventd`. Issues have been reported regarding the reliability of services that are tighly integrated with `systemd-udev` -- notably `gvfs` and `udisks2`, and it is possible that end users will need to write custom `udev` rules to support any uncommon hardware not covered by the stock rules shipped by `keventd`.

This service is imported by default. To enable it, add the following line to your system configuration:  

```nix
services.keventd.enable = true;
```

Software packages that ship `udev` rules can be installed and read by `keventd` with the following:

```nix
services.udev.packages = [ pkgs.libtmp.out ];
```

`services.udev` does not need to be enabled for this option to apply.

#### `mdevd`

[`mdevd`](https://skarnet.org/software/mdevd/) is a lightweight device manager from the Skarnet/s6 family of Linux system utilities. It is designed to be a drop in replacement to the `mdev` device manager included in the BusyBox software suite. It is by far the leanest of the other three services listed, and it has the narrowest hardware compatibility. It is ideal for systems with limited resources or those with little need for broad hardware support beyond standard input and storage devices. Programs and services dealing with low level input, notably `pipewire` and most graphical environments, will require recompilation with `libudev-zero` in order to function properly. `gvfs` and `udisks2` will not work with this device manager. If any additional hardware support is desired, a user will need to write custom rules utilising `mdevd` syntax, which is wholly unique to `udev` syntax. Examples for what these rules look like may be found [here](https://git.lin.moe/aports/lin/mdev-helper/mdev.conf.html).

This service is imported by default. To enable it, add the following line to your system configuration:  

```nix
services.mdevd.enable = true;
```

You may supply additional device rules with the following options:

```nix
services.mdevd.coldplugRules = '''';
services.mdevd.hotplugRules = '''';
```

It is generally advised when running this device manager to set the value of `services.mdevd.nlgroups = 4` in order to rebroadcast kernel events to `libudev-zero`.

### The `getty` program

`getty` is a program that manages login terminals. `finit` ships with a built in `getty` implementation which is used by default when the `getty` service is enabled.

This service is not imported by default. To import and enable it, add the following to your system configuration:  

```nix
{ config, modules, ... }:
{
  services.getty.enable = true;
}
```

You may also switch your preferred `getty` implementation using the option `services.getty.package`, like so:

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
