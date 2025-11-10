# Format Preserves data into files using text or binary syntax.
# https://preserves.dev/

{ lib, pkgs }:

{ ... }@args:
let
  toPreserves = lib.generators.toPreserves args;
  literal =
    with lib.types;
    nullOr (oneOf [
      bool
      int
      float
      str
      (attrsOf literal)
      (listOf literal)
    ])
    // {
      description = "Preserves value";
    };
  convert =
    syntax: name: value:
    pkgs.writeTextFile {
      name =
        let
          ext =
            {
              binary = ".prb";
              text = ".pr";
            }
            .${syntax};
        in
        if lib.hasSuffix ext name then name else "${name}${ext}";
      text = toString (map toPreserves value);
      checkPhase = ''
        ${lib.getExe pkgs.preserves-tools} convert \
          --output-format ${syntax} \
          <$target >tmp.pr && mv tmp.pr $target
      '';
      passthru = {
        inherit value;
      }
      // {
        # For each syntax the alternative
        # is available in passthru.
        binary.text = convert "text" name value;
        text.binary = convert "binary" name value;
      }
      .${syntax};
    };
in
{
  inherit literal;
  type = lib.types.listOf literal;

  generate = convert "text";

  # Hack to make Preserves records with < >.
  __findFile =
    _: _record: fields:
    fields ++ [ { inherit _record; } ];
}
