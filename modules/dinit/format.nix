{ pkgs, lib }:
let
  mkValueString =
    v:
    if lib.isInt v then
      toString v
    else if lib.isString v then
      v
    else if true == v then
      "yes"
    else if false == v then
      "no"
    else
      toString v;

  base = pkgs.formats.keyValue {
    listsAsDuplicateKeys = true;
    mkKeyValue = k: v: "${k} = ${mkValueString v}";
  };

  spaceSeparated = [
    "options"
    "load-options"
  ];
in
{
  inherit (base) type;

  generate =
    name: value:
    let
      transformedValue = lib.mapAttrs (
        key: val:
        if lib.isList val && lib.elem key spaceSeparated then
          lib.concatStringsSep " " (map toString val)
        else
          val
      ) (lib.filterAttrs (_: v: v != null && v != [ ]) value);
    in
    base.generate name transformedValue;
}
