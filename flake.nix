{
  description = "A collection of overlays, modules, libs, and templates for working with finix";

  outputs =
    { self }:
    let
      sources = import ./lon.nix;
      lib = import (sources.nixpkgs + "/lib");

      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];

      pkgsFor =
        system:
        import sources.nixpkgs {
          inherit system;
          config = {
            allowInsecurePredicate = _: true;
            allowUnfreePredicate = _: true;
          };

        };

      forAllSystems = lib.genAttrs systems;
    in
    {
      nixosModules = import ./modules;

      lib.finixSystem =
        {
          lib ? null,
          specialArgs ? { },
          modules ? [ ],
          ...
        }:
        let
          config = lib.evalModules {
            class = "nixos";
            specialArgs = lib.recursiveUpdate { modules = self.nixosModules; } specialArgs;
            modules = [ self.nixosModules.default ] ++ modules;
          };
        in
        config
        // {
          inherit (config._module.args) pkgs;
          inherit lib;
        };

      checks = forAllSystems (system: import ./tests { pkgs = pkgsFor system; });

      formatter = forAllSystems (system: (pkgsFor system).nixfmt-tree);
    };
}
