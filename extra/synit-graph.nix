# An expression that generates a graphviz graph for
# a Synit system configuration.

{
  config,
  lib,
  pkgs,
}:

let
  inherit (builtins) attrNames;
  inherit (lib)
    attrsToList
    concatMapStrings
    replaceString
    ;

  toRecord = fields: builtins.toJSON "<${toString fields}>";

  milestone =
    s:
    toRecord [
      "milestone"
      s
    ];
  daemon =
    s:
    toRecord [
      "daemon"
      s
    ];

  coreToDaemons =
    config.synit.core.daemons
    |> attrNames
    |> concatMapStrings (name: ''
      "<milestone core>" -> ${daemon name};
    '');

  dependsEdges =
    config.synit.depends
    |> concatMapStrings (rel: ''
      ${toRecord rel.key} -> ${toRecord rel.dependee.key};
    '');

in
pkgs.writeText "synit.dot" ''
  digraph ${builtins.toJSON "synit"} {
  ${dependsEdges}
  ${coreToDaemons}
  }
''
