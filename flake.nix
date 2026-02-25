{
  description = "A collection of overlays, modules, libs, and templates for working with finix";

  outputs =
    { self }:
    {
      nixosModules = import ./modules;

      lib.finixSystem =
        {
          lib ? null,
          specialArgs ? { },
          modules ? [ ],
          ...
        }:
        lib.evalModules {
          inherit specialArgs;

          modules = [ self.nixosModules.default ] ++ modules;
        };

      templates = {
        default = self.templates.desktop-greetd;

        desktop-greetd = {
          path = ./templates/desktop-seatd;
          description = "A simple desktop running the niri scrollable-tiling wayland compositor";
        };

        # TODO: desktop-logind
      };
    };
}
