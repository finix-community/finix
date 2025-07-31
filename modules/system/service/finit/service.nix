{ lib, config, pkgs, ... }:
let
  inherit (lib)
    concatMapAttrsStringSep
    escapeShellArg
    escapeShellArgs
    mkAliasOptionModule
    mkOption
    types
    ;
in
{
  imports = [ (mkAliasOptionModule [ "finit" "service" ] [ "finit" "services" "" ]) ];

  options = {
    finit.services = mkOption {
      description = ''
        This module configures Finit services.
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
    finit.services."" = {
      command = escapeShellArgs config.process.argv;
    };
  };
}
