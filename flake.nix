{
  description = "A collection of overlays, modules, libs, and templates for working with finix";

  outputs =
    { self }:
    {
      finixModules = import ./modules;

      lib.finixSystem =
        {
          lib ? null,
          specialArgs ? { },
          modules ? [ ],
          ...
        }:
        let
          config = lib.evalModules {
            class = "finix";
            specialArgs = lib.recursiveUpdate { modules = self.finixModules; } specialArgs;
            modules = [
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

      formatter =
        let
          sources = import ./lon.nix;
          lib = import (sources.nixpkgs + "/lib");

          pkgsFor = system: import sources.nixpkgs { inherit system; };
        in
        lib.genAttrs' [ "aarch64-linux" "x86_64-linux" ] (
          system: lib.nameValuePair system (pkgsFor system).nixfmt-tree
        );
    };
}
