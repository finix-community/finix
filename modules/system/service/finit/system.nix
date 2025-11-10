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

  makeServices =
    prefixes: service:
    concatMapAttrs (
      name: module:
      let
        label = if name == "" then prefixes else prefixes ++ [ name ];
      in
      {
        "${concatStringsSep "-" label}" =
          { ... }:
          {
            imports = [ module ];
          };
      }
    ) service.finit.services
    // concatMapAttrs (
      subServiceName: subService: makeServices (prefixes ++ [ subServiceName ]) subService
    ) service.services;
in
{
  # Assert Finit services for those defined in isolation to the system.
  config = mkIf config.finit.enable {

    finit.services = concatMapAttrs (
      topLevelName: topLevelService: makeServices [ topLevelName ] topLevelService
    ) config.system.services;
  };

}
