# finix

<p align="center">
  <a href="https://nixos.org"><img src="https://img.shields.io/badge/Built_with-Nix-5277C3?logo=nixos&logoColor=white" alt="Built with Nix"></a>
  <a href="https://discord.gg/RA98NxUd"><img src="https://img.shields.io/badge/Discord-Join-5865F2?logo=discord&logoColor=white" alt="Discord"></a>
</p>

> `finix` - a daily-drivable experimental os, featuring [finit](https://github.com/finit-project/finit) as pid 1, to explore the NixOS design space

While exploring the NixOS design space I had several topics in mind:

- [NixOS evaluation speed regression](https://github.com/NixOS/nixpkgs/issues/79943)
- [NixOS always imports all modules](https://github.com/NixOS/nixpkgs/issues/137168)
- [modular services](https://github.com/NixOS/nixpkgs/pull/372170)
- [decoupling services](https://discourse.nixos.org/t/pre-rfc-decouple-services-using-structured-typing/58257)
- [NixNG](https://github.com/nix-community/NixNG)
- [sixos](https://discourse.nixos.org/t/sixos-a-nix-os-without-systemd/58141)
- [nixbsd](https://github.com/nixos-bsd/nixbsd)

Now that `finix` is running on my laptop I have a working base for experimentation. More to come.

---

An example of defining a `finit` service in `nix`:

```
{ config, pkgs, lib, ... }:
{
  finit.services.network-manager = {
    description = "network manager service";
    runlevels = "2345";
    conditions = "service/syslogd/ready";
    command = "${pkgs.networkmanager}/bin/NetworkManager -n";
  };
}
```

`finix` is currently running on my ~spare~ primary laptop:

- with `finit` instead of `systemd` as the init system
- with `seatd` instead of `elogind` as the seat manager
- with `mdevd` instead of `eudev` as the device manager
- using [niri](https://github.com/YaLTeR/niri) as my `wayland` compositor

![niri-desktop-screenshot](https://github.com/user-attachments/assets/1bcfab8d-d363-4a48-beb5-27ec9843a683)

`finix` initially ran:
- in an `incus` container
- in a `nspawn` container
- on `virtualbox`
- with `x11`

None of the above methods have been attempted in some time.
