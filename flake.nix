{
  description = "A collection of overlays, modules, libs, and templates for working with finix";

  outputs =
    { self }:
    let
      sources = import ./lon.nix;
      lib = import (sources.nixpkgs + "/lib");

      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: lib.genAttrs systems (system: f (import sources.nixpkgs { inherit system; }));
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
            modules = [
              self.nixosModules.default
              ({pkgs,...}:{ services.nix-daemon.flake.source = toString pkgs.path; })
            ]
            ++ modules;
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
