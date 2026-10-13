# simplified libconfuse format for nixpkgs
{ pkgs, lib }:
{
  sections ? [ ],
}:
let
  render =
    value:
    if lib.isBool value then
      lib.boolToString value
    else if lib.isString value then
      ''"${value}"''
    else if lib.isInt value || lib.isFloat value then
      toString value
    else if lib.isList value then
      "{ ${lib.concatMapStringsSep ", " render value} }"
    else
      throw "libconfuse: cannot render value of type ${builtins.typeOf value}";

  renderBlock =
    indent: header: body:
    let
      inner = renderAttrs "${indent}  " body;
    in
    if inner == "" then "${indent}${header} { }" else "${indent}${header} {\n${inner}\n${indent}}";

  renderAttr =
    indent: name: value:
    if lib.isAttrs value && !lib.isDerivation value then
      if lib.elem name sections then
        lib.concatStringsSep "\n" (lib.mapAttrsToList (title: renderBlock indent "${name} ${title}") value)
      else
        renderBlock indent name value
    else
      "${indent}${name} = ${render value}";

  renderAttrs =
    indent: attrs:
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (renderAttr indent) (lib.filterAttrs (_: v: v != null) attrs)
    );
in
{
  type =
    with lib.types;
    let
      valueType =
        nullOr (oneOf [
          bool
          int
          float
          str
          (attrsOf valueType)
          (listOf valueType)
        ])
        // {
          description = "libconfuse value";
        };
    in
    valueType;

  lib = {
    inherit render renderAttr renderAttrs;
  };

  generate = name: value: pkgs.writeText name (renderAttrs "" value + "\n");
}
