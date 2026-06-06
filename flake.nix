{
  description = "A collection of overlays, modules, libs, and templates for working with finix";

  outputs = {self}: {
    finixModules = import ./modules;

    lib.finixSystem = {
      lib ? null,
      specialArgs ? {},
      modules ? [],
      ...
    }: let
      config = lib.evalModules {
        class = "finix";
        specialArgs = lib.recursiveUpdate {modules = self.finixModules;} specialArgs;
        modules =
          [
            ({lib, config, ...}: {
              options.nixosOptions = lib.mkOption {
                type = lib.types.listOf lib.types.deferredModule;
                default = [];
              };

              options.nixosModules = lib.mkOption {
                type = lib.types.submoduleWith {
                  modules = config.nixosOptions;
                  class = "nixos";
                };
                default = {};
              };

              imports = [ config.nixosModules ];
            })
            self.finixModules.default
          ]
          ++ modules;
      };
    in
      config
      // {
        inherit (config._module.args) pkgs;
        inherit lib;
      };
  };
}
