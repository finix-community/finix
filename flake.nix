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
              options.nixos = lib.mkOption {
                default = {};
                type = lib.types.submoduleWith {
                  modules = [
                    ({config, lib, ...}: {
                      options.options = lib.mkOption {
                        type = lib.types.listOf lib.types.deferredModule;
                        default = [];
                      };

                      options.config = lib.mkOption {
                        type = lib.types.submoduleWith {
                          modules = config.options;
                          class = "nixos";
                        };
                        default = {};
                      };
                    })
                  ];
                };
              };

              imports = [ config.nixos.config ];
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
