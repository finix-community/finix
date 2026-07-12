{ lib }:
let
  inherit (import ../lib/types.nix { inherit lib; }) pathOrStr program;

  rlimitsType =
    let
      complexType = lib.types.submodule {
        options = {
          soft = lib.mkOption {
            type = lib.types.nullOr (lib.types.either (lib.types.enum [ "unlimited" ]) lib.types.int);
            default = null;
            description = ''
              The value that the kernel enforces for this resource.
            '';
          };

          hard = lib.mkOption {
            type = lib.types.nullOr (lib.types.either (lib.types.enum [ "unlimited" ]) lib.types.int);
            default = null;
            description = ''
              The ceiling for the soft limit.
            '';
          };
        };
      };
    in
    lib.types.attrsOf (
      lib.types.oneOf [
        (lib.types.enum [ "unlimited" ])
        lib.types.int
        complexType
      ]
    );
in
{
  inherit pathOrStr program rlimitsType;
}
