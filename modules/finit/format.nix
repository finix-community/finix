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
  # The keys a block may carry, transcribed from the cfg_opt_t tables in finit's src/conf.c.
  # Anything else is a parse error, and a parse error takes the whole .conf file down at boot, which is a rotten way to find out about a typo.
  svcSchema = [
    "description"
    "desc"
    "command"
    "runlevel"
    "conditions"
    "cond"
    "user"
    "group"
    "extra-groups"
    "envfile"
    "env"
    "pidfile"
    "pidfile-create"
    "notify"
    "type"
    "manual-start"
    "manual"
    "remain-after-exit"
    "remain"
    "respawn"
    "restart"
    "restart-max"
    "restart-sec"
    "oncrash"
    "reload-signal"
    "required"
    "stop-signal"
    "halt"
    "stop-timeout"
    "kill"
    "exec-start-pre"
    "exec-start-pre-timeout"
    "exec-start-ready"
    "exec-start-ready-timeout"
    "exec-stop"
    "exec-stop-timeout"
    "exec-stop-post"
    "exec-stop-post-timeout"
    "exec-reload"
    "exec-reload-timeout"
    "exec-cleanup"
    "exec-cleanup-timeout"
    "capabilities"
    "caps"
    "pam"
    "runtime-dir"
    "state-dir"
    "cache-dir"
    "logs-dir"
    "config-dir"
    "runtime-dir-mode"
    "state-dir-mode"
    "cache-dir-mode"
    "logs-dir-mode"
    "config-dir-mode"
    "runtime-dir-preserve"
    "conflicts"
    "provides"
    "if"
    "tty"
  ];

  ttySchema = [
    "runlevel"
    "conditions"
    "cond"
    "device"
    "baud"
    "term"
    "noclear"
    "nowait"
    "nologin"
    "passenv"
    "command"
    "notty"
    "rescue"
  ];

  # RLIMIT_OPTS() in conf.c: a closed set so a misspelled resource is fatal
  rlimitSchema =
    let
      resources = [
        "as"
        "core"
        "cpu"
        "data"
        "fsize"
        "locks"
        "memlock"
        "msgqueue"
        "nice"
        "nofile"
        "nproc"
        "rss"
        "rtprio"
        "rttime"
        "sigpending"
        "stack"
      ];
    in
    lib.concatMap (r: [
      r
      "soft.${r}"
      "hard.${r}"
    ]) resources;

  # the soft/hard prefix of a { soft = …; hard = …; } limit flattened
  rlimitEntries =
    r:
    lib.concatMapAttrs (
      n: v:
      if lib.isAttrs v then
        lib.optionalAttrs (v.soft != null) { "soft.${n}" = v.soft; }
        // lib.optionalAttrs (v.hard != null) { "hard.${n}" = v.hard; }
      else
        { ${n} = v; }
    ) r;

  unknownKeys = schema: set: builtins.filter (k: !(lib.elem k schema)) (builtins.attrNames set);

  # one assertion per stanza so the message can name it
  checkStanza =
    path: schema: svc:
    let
      unknown = unknownKeys schema (mkEntries svc);
    in
    lib.optional (unknown != [ ]) {
      assertion = false;
      message = "${path} would be written with keys finit v5 does not accept: ${lib.concatStringsSep ", " unknown}";
    };

  checkRlimit =
    path: rlimits:
    let
      unknown = unknownKeys rlimitSchema (rlimitEntries rlimits);
    in
    lib.optional (unknown != [ ]) {
      assertion = false;
      message = "${path} has resource limits finit v5 does not accept: ${lib.concatStringsSep ", " unknown}";
    };
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
    rlimitEntries
    unknownKeys
    checkStanza
    checkRlimit
    svcSchema
    ttySchema
    rlimitSchema
    ;
}
