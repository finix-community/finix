/**
  Translate a literal Nix expression to Preserves text syntax.

  # Inputs

  Options
  : ignoreNulls
    : Whether null values in attrsets are dropped.
  : rawStrings
    : Whether Nix string values should be JSON-quoted or left as-is.

  Value
  : The literal value to convert to Preserves text.
*/
{ lib }:
{
  ignoreNulls ? true,
  rawStrings ? false,
}:
let toPreserves =
    let
      inherit (lib) isDerivation;
      concatItems = toString;
      mapToSeq = v: toString (map toPreserves v);
      recordLabel = list:
        with builtins;
        let len = length list; in
        if len == 0 then null
        else
          let end = elemAt list (len - 1); in
          if (lib.isAttrs end) && (attrNames end) == [ "_record" ]
          then end._record
          else null;
      dictTuple = key: val: "${key}: ${toPreserves val}";
      attrToDict =
        if !ignoreNulls then dictTuple else key: val: if val != null then dictTuple key val else "";
      convert = {
        int = toString;
        bool = v: if v then "#t" else "#f";
        string = if rawStrings then lib.id else builtins.toJSON;
        path = v: toPreserves (toString v);
        null = _: "<null>";
        set = v:
          if v ? __toPreserves then v.__toPreserves (builtins.removeAttrs v [ "__toPreserves" ])
          else if (isDerivation v) then (builtins.toJSON v)
          else "{ ${concatItems (lib.attrsets.mapAttrsToList attrToDict v)} }";
        list = v:
          let label = recordLabel v; in
          if label == null then "[ ${mapToSeq v} ]" else "<${label} ${mapToSeq (lib.lists.init v)}>";
        lambda = abort "generators.toPreserves cannot convert lambdas";
        float = builtins.toJSON;
      };
    in v: convert.${builtins.typeOf v} v;
in toPreserves
