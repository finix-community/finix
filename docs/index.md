# `finix`

`finix` is an experimental GNU/Linux distribution built around the `nix` package manager. It uses [finit](https://github.com/finit-project/finit) instead of `systemd` as its init system and service supervisor. By default, it seeks to be:

- minimal
- unopinionated
- *extremely* flexible

`finix` is fully capable as a:

- daily-drivable desktop/laptop
- homelab server
- media center
- gaming pc
- ... and more!

## Installation

`finix` does not yet have a disk image available to download - installation will need to take place from a standard NixOS image, which can be downloaded [here](https://nixos.org/download#nixos-iso). You may download and burn either the minimal image or the graphical image and the steps will remain the same. 

For an installation guide, please see one of the following repositories on Codeberg. Credits to [@xZecora](https://github.com/xZecora) for writing these.

- [flake-based setup](https://codeberg.org/vitrial/finix-config)
- [channel-based setup](https://codeberg.org/vitrial/finix-channel-install)

# See also

- [finix options search](https://finix-community.github.io/finix/options.html)
- [finit project](https://finit-project.github.io/)
- [finix profiles](https://github.com/finix-community/profiles)
- [finix community modules](https://github.com/finix-community/community-modules/)
