let
  programModules = builtins.mapAttrs (dir: _: ./programs/${dir}) (
    builtins.removeAttrs (builtins.readDir ./programs) [
      "README.md"

      # required modules - included by default
      "shadow"
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

  providerModules =
    builtins.removeAttrs (builtins.readDir ./providers) [ "README.md" ]
    |> builtins.attrNames
    |> builtins.map (value: ./providers/${value});
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
      ./nixpkgs
      ./programs/shadow
      ./security
      ./services/dbus
      ./services/elogind
      ./services/mdevd
      ./services/seatd
      ./services/udev
      ./system/activation
      ./system/activation/specialisation.nix
      ./system/nixos-rebuild-compat.nix
      ./time
      ./users
      ./xdg
    ]
    ++ providerModules;
  };
}
// programModules
// serviceModules
