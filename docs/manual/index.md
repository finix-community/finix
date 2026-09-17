# `finix` - fast init nix

<p align="center">
  <a href="https://nixos.org"><img src="https://img.shields.io/badge/Built_with-Nix-5277C3?logo=nixos&logoColor=white" alt="Built with Nix"></a>
  <a href="https://discord.gg/nVe5Zkaypg"><img src="https://img.shields.io/badge/Discord-Join-5865F2?logo=discord&logoColor=white" alt="Discord"></a>
</p>

`finix` is an experimental GNU/Linux distribution built around the `nix` package manager. It uses [`finit`](https://github.com/finit-project/finit) instead of `systemd` as its init system and service supervisor. By default, it seeks to be:

- minimal
- unopinionated
- *extremely* flexible

`finix` is fully capable as a:

- daily-drivable desktop/laptop
- homelab server
- media center
- gaming pc
- ... and more!

## `finix` is not a fork

`finix` is an independent distribution that tries to remain similar to NixOS in how an end user configures their system, but with one key difference: while NixOS imports all available configuration modules by default, `finix` only imports a small handful of defaults essential for a bootable system. The end user is responsible for importing the rest of the modules required to configure their system to their specifications. A welcome side effect of this smaller selection of default imports is greatly reduced evaluation times. Minimal defaults, alongside `finix's` "assume nothing about the user" philosophy, and its preference for remaining as close to upstream authors in its software configuration as much as possible, means that an average `finix` system is (usually) much lighter than a similarly configured NixOS system (and more hackable!). Refer to [Comparing `finix` and NixOS](./finix-vs-nixos.md) for a more detailed comparison between `finix` and NixOS.

Contributions to the `finix` ecosystem are always welcome. If you would like to improve this documentation, contribute a software module, or make any improvements to core `finix` functionality, you are more than welcome to do so.

## Getting started

If you are interested in running `finix`, feel free to consult the [install guide](./installation.md).

## Quick Links

- [finit project](https://finit-project.github.io/) - the init system used for `finix`
- [finix community modules](https://github.com/finix-community/community-modules/) - community modules for `finix`
- [desktop show-and-tell](https://github.com/finix-community/finix/discussions/1) - browse other `finix` users' desktops!
