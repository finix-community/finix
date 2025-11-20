{
  description = "A collection of overlays, modules, libs, and templates for working with finix";

  outputs =
    { self }:
    {
      nixosModules = import ./modules;

      overlays = {
        # software required for finix to operate
        default = import ./overlays/default.nix;
      };

      lib.finixSystem =
        {
          lib ? null,
          specialArgs ? { },
          modules ? [ ],
          ...
        }:
        let
          sources = import ./lon.nix;
          modulesPath = toString sources.nixpkgs + "/nixos/modules";
        in
        lib.evalModules {
          specialArgs =
            lib.optionalAttrs (!specialArgs ? modulesPath) {
              # pull in a pinned copy of nixpkgs if not provided by the caller
              inherit modulesPath;
            }
            // specialArgs;

          modules = [ self.nixosModules.default ] ++ modules;
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
