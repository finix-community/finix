{
  description = "A minimal finix system";

  inputs = {
    finix.url = "github:finix-community/finix?ref=finit-4.16";
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    { finix, nixpkgs, ... }:
    let
      inherit (pkgs) lib;

      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in
    {
      nixosConfigurations.default = finix.lib.finixSystem {
        inherit pkgs lib;

        system = "x86_64-linux";
        specialArgs = {
          modulesPath = toString nixpkgs + "/nixos/modules";
        };

        modules = [
          ./configuration.nix
          { nixpkgs.pkgs = pkgs; }
        ]
        ++ lib.attrValues finix.nixosModules;
      };
    };

  nixConfig = {
    extra-experimental-features = [
      "flakes"
      "nix-command"
      "pipe-operators"
    ];
  };
}
