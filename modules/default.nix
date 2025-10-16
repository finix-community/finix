let
  programModules = builtins.mapAttrs (dir: _:
    ./programs/${dir}
  ) (builtins.removeAttrs (builtins.readDir ./programs) [ "README.md" ]);

  providerModules = builtins.mapAttrs (dir: _:
    ./providers/${dir}
  ) (builtins.removeAttrs (builtins.readDir ./providers) [ "README.md" ]);

  serviceModules = builtins.mapAttrs (dir: _:
    ./services/${dir}
  ) (builtins.removeAttrs (builtins.readDir ./services) [ "README.md" ]);
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
      ./synit
      ./system/activation
      ./system/service
      ./time
      ./users
      ./xdg
    ];
  };
} // programModules // providerModules // serviceModules
