{
  description = "A collection of overlays, modules, libs, and templates for working with finix";

  outputs =
    { self }:
    let
      sources = import ./lon.nix;
      lib = import (sources.nixpkgs + "/lib");

      forAllSystems =
        function:
        lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (
          system: function (import sources.nixpkgs { inherit system; })
        );
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

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);

      devShells = forAllSystems (pkgs: {
        default = import ./shell.nix { inherit pkgs; };
      });
    };
}
