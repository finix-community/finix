{ lib }:
let
  # `"a"`/`1`/`true`, or `{ "a", "b" }` for a list.
  bfScalar =
    v:
    if lib.isBool v then
      (if v then "true" else "false")
    else if lib.isInt v then
      toString v
    else
      "\"" + lib.replaceStrings [ "\\" "\"" ] [ "\\\\" "\\\"" ] (toString v) + "\"";

  bfValue =
    v: if lib.isList v then "{ " + lib.concatMapStringsSep ", " bfScalar v + " }" else bfScalar v;

  # `null`/`""`/`[ ]`/`false` means "not set" and gets dropped, so callers can just
  # forward every option value and let unset flags default away.
  bfLines =
    entries:
    lib.filter (l: l != null) (
      lib.mapAttrsToList (
        k: v: if v == null || v == "" || v == [ ] || v == false then null else "    ${k} = ${bfValue v}"
      ) entries
    );

  bfIndent =
    b: lib.concatMapStringsSep "\n" (l: if l == "" then l else "    " + l) (lib.splitString "\n" b);

  mkBlock =
    type: title: entries: subBlocks:
    let
      body = bfLines entries ++ map bfIndent subBlocks;
    in
    "${type}${lib.optionalString (title != null) " ${title}"} {"
    + lib.optionalString (body != [ ]) ("\n" + lib.concatStringsSep "\n" body)
    + "\n}";

  mkTitle = name: id: if id == null then name else "${name}:${id}";

  # Stanza keys that are not finit settings: Nix-side identity, what becomes
  # its own (sub-)block or is folded away, and the deprecated spellings.
  nixOnlyKeys = [
    "enable"
    "name"
    "id"
    "settings"
    "cgroup"
    "rlimit"
    "log" # a block, never a scalar
    "environment"
    "path"
    "script"
    "nohup"
    "priority"
    "reload-triggers"

    # deprecated aliases, see the mkRenamedOptionModule calls
    "caps"
    "cleanup"
    "conflict"
    "env"
    "kill"
    "manual"
    "pid"
    "post"
    "pre"
    "ready"
    "reload"
    "remain"
    "restart"
    "restart_sec"
    "rlimits"
    "runlevels"
    "stop"
    "supplementary_groups"
  ];

  mkEntries =
    svc:
    removeAttrs svc nixOnlyKeys
    // lib.optionalAttrs (svc.nohup or false) { "reload-signal" = "none"; }
    // svc.settings;
in
{
  inherit
    bfScalar
    bfValue
    bfLines
    bfIndent
    mkBlock
    mkTitle
    mkEntries
    ;
}
