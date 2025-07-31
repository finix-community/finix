{ lib, config, ... }:
let
  inherit (lib)
    mkAliasOptionModule
    mkOption
    types
    ;
in
{
  imports = [ (mkAliasOptionModule [ "synit" "daemon" ] [ "synit" "daemons" "" ]) ];

  options = {
    synit.daemons = mkOption {
      description = ''
        This module configures Synit daemons.
      '';
      type = types.lazyAttrsOf types.deferredModule;
      default = { };
    };

    # Import this logic into sub-services also.
    # Extends the portable `services` option.
    services = mkOption {
      type = types.attrsOf (
        types.submoduleWith {
          class = "service";
          modules = [
            ./service.nix
          ];
        }
      );
    };
  };

  config = {
    synit.daemons."" = {
      inherit (config.process) argv;
    };
  };
}
