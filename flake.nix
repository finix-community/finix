{
  description = "A collection of overlays and modules for finix";

  outputs = { self }: let release = import ./.; in {
    nixosModules = release.modules;
    overlays = release.overlays;

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
