{
  description = "A simple desktop running the niri scrollable-tiling wayland compositor";

  inputs = {
    finix.url = "github:finix-community/finix";
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    { finix, nixpkgs, ... }:
    let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };

      os = pkgs.lib.evalModules {
        specialArgs = {
          inherit pkgs;
          # inherit (pkgs) lib;
          modulesPath = "${nixpkgs}/nixos/modules";
        };

        modules = [
          { nixpkgs.pkgs = pkgs; }
          ./configuration.nix
        ]
        ++ pkgs.lib.attrValues finix.nixosModules;
      };
    in
    {
      packages.x86_64-linux.default = os.config.system.topLevel;
    };

  nixConfig = {
    extra-experimental-features = [
      "flakes"
      "nix-command"
      "pipe-operators"
    ];
  };
}
