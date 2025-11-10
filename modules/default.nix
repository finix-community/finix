let
  programModules = builtins.mapAttrs (dir: _: ./programs/${dir}) (
    builtins.removeAttrs (builtins.readDir ./programs) [ "README.md" ]
  );

  serviceModules = builtins.mapAttrs (dir: _: ./services/${dir}) (
    builtins.removeAttrs (builtins.readDir ./services) [
      "README.md"

      # required modules - included by default
      "dbus"
      "elogind"
      "mdevd"
      "seatd"
      "tmpfiles"
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
      ./security
      ./services/dbus
      ./services/elogind
      ./services/mdevd
      ./services/seatd
      ./services/tmpfiles
      ./services/udev
      ./synit
      ./system/activation
      ./system/service
      ./time
      ./users
      ./xdg
    ]
    ++ providerModules;
  };
}
// programModules
// serviceModules
