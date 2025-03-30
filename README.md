# finix

> `finix` - an experimental os, featuring [finit](https://github.com/troglobit/finit) as pid 1, to explore the NixOS design space

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

`finix` is currently running on my spare laptop:

- without the excellent `systemd` init system
- with `seatd` instead of `elogind`
- using [niri](https://github.com/YaLTeR/niri) as my `wayland` compositor

![niri-desktop-screenshot](https://github.com/user-attachments/assets/3567af60-b090-43b8-87a2-984bcea85a3c)

`finix` initially ran:
- in an `incus` container
- in a `nspawn` container
- on `virtualbox`
- with `x11`

None of the above methods have been attempted in some time.
