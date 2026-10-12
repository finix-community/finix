# Comparing finix and NixOS

This page serves as a high level overview for the differences between finix and NixOS, and it is primarily targeted towards current NixOS users or those who are already familiar with the NixOS ecosystem.

## Init system

Finix utilizes [Finit](https://github.com/finit-project/finit) as its primary init system and service supervisor as a simple but capable alternative to systemd. It is primarily designed for use in small or embedded Linux systems, but it is fully capable on desktop and server devices with finix. Explaining Finit's full feature set is outside the scope of this document, but here are a few of the highlights:

- Simple but powerful condition system for handing dependencies
- Built-in getty
- Small tmpfiles implementation
- Readiness notification with support for systemd's `sd_notify()`
- Cgroup v2 support

Finit does not attempt nor want to implement the same level of functionality that systemd offers, but it implements *just enough* systemd-like functionality to allow most modern day Linux software to work with little to no issue without requiring much configuration. A benefit to using Finit for a nix based system is that it eliminates the need for complicated `switch-to-configuration` logic in order to ensure a clean generation switch.

In finix, defining a service with Finit is similar to defining a systemd unit under NixOS.

```nix
{ config, pkgs, lib, ... }:
{
  finit.services.network-manager = {
    description = "network manager service";
    conditions = "service/dbus/ready";
    command = "${cfg.package}/bin/NetworkManager -n";
  };
}
```

Finit does not yet have support for user-level service management, but progress towards this feature is being worked on and is scheduled for the next major version of Finit.

## Modules

By default, NixOS and all of its modules are automatically imported into the global configuration attribute set. A benefit to this approach is that users do not need to maintain a list of module imports, but this comes at a significant cost to evaluation times. Finix opts for a minimal set of defaults, requiring the end user to either maintain their own import list or to configure and enable a configuration profile. As a result, finix evaluation times are much faster in comparison to similarly configured NixOS systems.

Finix exposes modules not imported by default through the `modules` parameter. It is the equivalent to NixOS's builtin `modulesPath` attribute. Here is a functional example to illustrate the difference between enabling and configuring a NixOS module compared to a finix module.

Say a user would like to enable the service module for `chrony`, a network time synchronization daemon. Under NixOS, it would be as simple as adding this line to the system configuration:

```nix
{ config, ... }:
{
  # ...
  services.chrony.enable = true;
  # ...
}
```

If a user wanted to do the same on finix, they would need to add the `modules` input and explicitly import the module they need into scope. Like so:

```nix
{
  modules, # finix equivalent of nixos modulesPath
  config, 
  ...
}:
{
  imports = [ modules.chrony ];
  services.chrony.enable = true;
}
```

There are many modules in finix that have been renamed from their NixOS counterparts. Finix does not introduce any additional subcategories for program or service modules beyond the initial `programs.*` or `services.*`, and some software has been switched from the `programs` attribute set to `services` (and vice versa) due to how they are configured for finix. PipeWire is a notable example, as its configuration lives under `programs.pipewire` instead of `services.pipewire`. Consult the [options search](https://finix-community.github.io/finix/options.html) for a comprehensive list of all available configuration modules for finix.

### Default imports

The following is a list of default program and service modules that are available in the global scope without requiring a manual import.

#### `modules/programs`

```
coreutils
modprobe
plymouth
resolvconf
sh
shadow
```

#### `modules/services`

```
dbus
elogind
gardendevd
keventd
mdevd
seatd
sessiond
udev
```

## `providers`

This section is a brief introduction into the `providers` abstraction, a simple implementation of an idea proposed by [@ibizaman](https://github.com/ibizaman) for decoupling modules.

The `providers` abstraction is a simple but powerful tool to allow modules to reference each other without directly interfacing with them. It accomplishes this by *providing* generic interfaces for services or programs that implement similar functionality.

As an example, the `providers.scheduler` abstraction provides a generic interface for three scheduling services:

- `cron`
- `anacron`
- `fcron`

If a module needs to configure a scheduled task, they can do so using the `providers.scheduler.tasks` option without needing to directly reference any specific scheduler.

```nix
providers.scheduler.tasks = {
  logrotate = {
    interval = "daily";
    command = "${cfg.package}/bin/logrotate ${configFile}";
  };
};
```

On evaluation, the scheduler provider will execute logic that generates a configuration file for each of the three mentioned schedulers, provided that a user has a scheduler service enabled with the following:

```nix
{ modules, config, ... }:
{
  imports = [ services.anacron ];

  services.anacron.enable = true;
}
```

If a user does not have a scheduler service enabled, any scheduled task defined with `providers.scheduler.tasks` will simply be ignored.

Currently, there are provider abstractions for privilege escalation (`providers.privileges`), firewalls (`providers.firewall`), bootloaders (`providers.bootloader`), and resume-and-suspend functionality (`providers.resume-and-suspend`). See the providers section of [Configuring](./configuring.md) for more details.

## Hackability

Finix features a far leaner module set than NixOS, which is partially due to its age in comparison to NixOS. However, the modules that do exist are written to be as unopinionated and decoupled from one another as possible. Because of this, finix is an excellent way for users and developers to experiment with far more aspects of their system then they would be able to with NixOS without worrying about unexpected breakage. Many finix users have been able to successfully experiment with finix with the following results:

- sub 1 second boot times
- running a fully `musl-libc` based desktop
- systems with no stage 1
- systems with no stage 2
- installing finix onto [embedded boards](https://github.com/murdoa/finix-rk3506)
