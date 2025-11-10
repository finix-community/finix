{
  description = "A collection of overlays and modules for finix";

  outputs =
    { self }:
    {
      nixosModules = import ./modules;

      overlays = {
        # software required for finix to operate
        default = import ./overlays/default.nix;

        # work in progress overlay to build software in nixpkgs without systemd
        without-systemd = import ./overlays/without-systemd.nix;

        # can be used to relieve packages from requiring udev at runtime
        without-udev = import ./overlays/without-udev.nix;

        # apply modular services to packages for convenience
        modular-services = import ./overlays/modular-services.nix;
      };

      templates = {
        default = self.templates.desktop-greetd;

        desktop-greetd = {
          path = ./templates/desktop-seattd;
          description = "A simple desktop running the niri scrollable-tiling wayland compositor";
        };

        # TODO: desktop-logind
      };
    };
}
