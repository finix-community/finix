{
  lib,
  config,
  options,
  pkgs,
  ...
}:

let
  inherit (lib)
    concatMapAttrs
    mkOption
    types
    concatLists
    mapAttrsToList
    mkIf
    ;

  portable-lib = import ./portable/lib.nix { inherit lib; };
in
{
  imports = [
    ./finit/system.nix
    ./synit/system.nix
  ];

  options = {
    system.services = mkOption {
      description = ''
        A collection of modular services.
      '';
      type = types.attrsOf (
        types.submoduleWith {
          class = "service";
          modules = [
            ./portable/service.nix
            ./finit/service.nix
            ./synit/service.nix
          ];
          specialArgs = {
            # perhaps: features."systemd" = { };
            inherit pkgs;
          };
        }
      );
      default = { };
      visible = "shallow";
    };
  };

  config = {
    assertions = concatLists (
      mapAttrsToList (
        name: cfg: portable-lib.getAssertions (options.system.services.loc ++ [ name ]) cfg
      ) config.system.services
    );

    warnings = concatLists (
      mapAttrsToList (
        name: cfg: portable-lib.getWarnings (options.system.services.loc ++ [ name ]) cfg
      ) config.system.services
    );
  };

}
