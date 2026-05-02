let
  programModules = builtins.mapAttrs (dir: _: ./programs/${dir}) (
    builtins.removeAttrs (builtins.readDir ./programs) [
      "README.md"

      # required modules - included by default
      "plymouth"
      "resolvconf"
      "shadow"

      # deprecated, remove at some point
      "openresolv"
    ]
  );

  serviceModules = builtins.mapAttrs (dir: _: ./services/${dir}) (
    builtins.removeAttrs (builtins.readDir ./services) [
      "README.md"

      # required modules - included by default
      "dbus"
      "elogind"
      "mdevd"
      "seatd"
      "udev"
    ]
  );

  providerModules = builtins.map (value: ./providers/${value}) (
    builtins.attrNames (builtins.removeAttrs (builtins.readDir ./providers) [ "README.md" ])
  );
in
{
  default = {
    imports = [
      ./boot
      ./environment
      ./filesystems
      ./finit
      ./fonts
      ./hardware
      ./i18n
      ./misc
      ./networking
      ./nixos
      ./nixpkgs
      ./programs/plymouth
      ./programs/resolvconf
      ./programs/shadow
      ./security
      ./services/dbus
      ./services/elogind
      ./services/mdevd
      ./services/seatd
      ./services/udev
      ./system/activation
      ./system/activation/specialisation.nix
      ./system/nixos-compat.nix
      ./time
      ./users
      ./xdg
    ]
    ++ providerModules;
  };
}
// programModules
// serviceModules
