# finix - fast init nix

<p align="center">
  <a href="https://nixos.org"><img src="https://img.shields.io/badge/Built_with-Nix-5277C3?logo=nixos&logoColor=white" alt="Built with Nix"></a>
  <a href="https://discord.gg/nVe5Zkaypg"><img src="https://img.shields.io/badge/Discord-Join-5865F2?logo=discord&logoColor=white" alt="Discord"></a>
</p>

Finix is an experimental Linux distribution built around the Nix package manager. It uses [Finit](https://github.com/finit-project/finit) instead of systemd as its init system and service supervisor. By default, it seeks to be:

- minimal
- unopinionated
- *extremely* flexible

Finix is fully capable as a:

- daily-drivable desktop/laptop
- homelab server
- media center
- gaming pc
- ... and more!

## finix is not a fork

Finix is a nix-based distribution that ships its own independent module set, and these modules are written in such a way that any NixOS user familiar with the ecosystem can pick up and start using finix with relative ease. One important difference between finix and NixOS is that the former imports all of its modules into the global configuration attribute set by default, while finix only imports a small handful. While this does leave the end user responsible for importing any modules required to configure their system, a welcome side effect of this is greatly reduced evaluation times, as well as far looser coupling between modules reducing the possibility of breakage. Minimal defaults, alongside finix's "assume nothing about the user" philosophy, and its preference for remaining as close to upstream authors in its software configuration as much as possible, means that an average finix system is (usually) much lighter than a similarly configured NixOS system (and more hackable!). See [Comparing finix and NixOS](./finix-vs-nixos.md) for more details.

Contributions to the finix ecosystem are always welcome. If you would like to improve this documentation, contribute a software module, or make any improvements to core finix functionality, you are more than welcome to do so.

## Getting started

See the [install guide](./installation.md). If you have an existing finix system and are looking for more information on configuring it, see [Configuring.md](./configuring.md).

## Quick Links

- [finit project](https://finit-project.github.io/) - the init system used for finix
- [finix community modules](https://github.com/finix-community/community-modules/) - community modules for finix
- [desktop show-and-tell](https://github.com/finix-community/finix/discussions/1) - browse other finix users' desktops!
