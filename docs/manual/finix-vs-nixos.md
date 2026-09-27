# Comparison of `finix` and NixOS

On the surface, `finix` and NixOS present a lot of similarities: `finix` utilizes the module system of `nix` in a very similar fashion to NixOS. It has identical syntax for enabling programs and services as NixOS. However, there are several key differences that distinguishes `finix` from NixOS.

## Init system

As mentioned in the introduction, `finix` utilizes [`finit`](https://github.com/finit-project/finit) as its primary init system and service supervisor in place of `systemd`. Explaining the full breadth of `finit's` features is outside the scope of this document, but there are a few advantages of using `finit` over `systemd` as PID 1.

1. Great balance of capability and ambition. `finit` does not want nor attempt to do everything that `systemd` does; however, the capabilities it does have make `finit` a viable `systemd` alternative fit for a leaner Linux distribution that prefers to decouple features from the init system and delegate them to other programs.
2. No complex `switch-to-configuration` logic. `finit` automatically handles the starting and stopping of services without needing a complicated set of `switch-to-configuration` logic to handle the amount of equivalent `systemd` services needed to ensure a clean switch.

Defining a service in `finit` is similar to defining a `systemd` unit under NixOS.

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

A significant difference between `finit` and `systemd` is a lack of user-level service management, at least for the current packaged version of `finit` (v5.0-rc1 at the time of writing). However, there is a module set under [`community-modules`](https://github.com/finix-community/community-modules) that allows users to define and enable user-level services utilizing the `dinit` service supervisor, which may serve as a substitution for this functionality. See [Configuration](./configuring.md) for more details.

## Modules

At a baseline, NixOS and all of its modules are automatically imported into the global configuration attribute set by default. A benefit to this approach is that the end user does not need to manually maintain a list of imports for modules they would like to enable, but it comes at a significant cost to evaluation times. `finix` opts for a set of minimal defaults, shifting the responsibility over to the end user to maintain their own import list, or to configure and enable one of the available profiles.

Here is an example of what that looks like in practice.

Say a user would like to enable the service module for `chrony`, a network time synchronization daemon. Under NixOS, it would be as simple as adding this line to your `configuration.nix`:

```nix
{ config, ... }:
{
  # ...
  services.chrony.enable = true;
  # ...
}
```

If a user wanted to do the same on `finix`, they would first need to add an `imports` statement, along with an extra function input at the top of their configuration file. Like so:

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

There are many modules in `finix` that have been renamed from their NixOS counterparts -- be sure to check the [options search](https://finix-community.github.io/finix/options.html) for a comprehensive list.

### Default imports

The following is a list of default program and service modules that are available in the global configuration without requiring a manual import.

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

## `providers` namespace

This section will only be a brief introduction into the `providers` abstraction, which is a simple implementation of an idea proposed by [@ibizaman](https://github.com/ibizaman) for decoupling modules.

The `providers` abstraction is a simple but powerful tool to allow different modules to reference each other without directly importing them. It also allows for generic implementations of different services that provide similar functionality.

As an example, the `providers.scheduler` abstraction provides a generic interface for three variations of the `cron` scheduling service:

- `cron`
- `anacron`
- `fcron`

If a module author requires a scheduled task to be written, they can define one using the generic `providers.scheduler` without needing to import any of these services modules.  

```nix
providers.scheduler.tasks = {
  logrotate = {
    interval = "daily";
    command = "${cfg.package}/bin/logrotate ${configFile}";
  };
};
```

On evaluation, the scheduler provider will execute logic that generates a corresponding `cron` configuration file for each of the three previously mentioned scheduler implementations, provided that a user has a scheduler enabled with the following:

```nix
{ modules, config, ... }:
{
  imports = [ services.anacron ];

  services.anacron.enable = true;
}
```

In summary, instead of a module directly asking for `cron` specifically, it can simply ask for a scheduler, and whichever scheduler the user has enabled in their configuration will be what is used to execute the scheduled task. Currently, there are provider abstractions for privilege escalation (`providers.privileges`), firewalls (`providers.firewall`), bootloaders (`providers.bootloader`), and resume-and-suspend functionality (`providers.resume-and-suspend`). See the providers section of [Configuring](./configuring.md) for more details.

## Hackability

`finix` features a far leaner module set than NixOS -- partly due to its age, and also because `finix` chooses to ship modules that are as unopinionated and decoupled from one another as possible. Because of this, `finix` is an excellent way for users and developers to experiment with far more aspects of their system then they would be able to with NixOS without worrying about breaking an unrelated module. Many `finix` users have been able to successfully experiment with `finix` and yield the following results:

- sub 1 second boot times
- running a fully `musl-libc` based desktop
- systems with no stage 1
- systems with no stage 2
- installing `finix` onto [embedded boards](https://github.com/murdoa/finix-rk3506)
