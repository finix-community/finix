{
  lib,
  config,
  options,
  pkgs,
  ...
}:

let
  inherit (lib)
    attrNames
    types
    concatLists
    concatMapAttrs
    concatStringsSep
    mapAttrs
    mapAttrsToList
    mkIf
    ;

  makeDaemons =
    prefixes: service:
    concatMapAttrs (
      name: module:
      let label = if name == "" then prefixes else prefixes ++ [ name ];
      in { "${concatStringsSep "-" label}" = { ... }: { imports = [ module ]; }; }
    ) service.synit.daemons
    // concatMapAttrs (
      subServiceName: subService: makeDaemons (prefixes ++ [ subServiceName ]) subService
    ) service.services;
in
{
  # Assert Synit services for those defined in isolation to the system.
  config = mkIf config.synit.enable {

    synit.daemons = concatMapAttrs (
      topLevelName: topLevelService: makeDaemons [ topLevelName ] topLevelService
    ) config.system.services;
  };

}
