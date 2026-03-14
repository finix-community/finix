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
    };
}
