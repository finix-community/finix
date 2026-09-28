{ lib, pkgs }:
let
  pathOrStr = with lib.types; coercedTo path (x: "${x}") str;
  program =
    lib.types.coercedTo (
      lib.types.package
      // {
        # require mainProgram for this conversion
        check = v: v.type or null == "derivation" && v ? meta.mainProgram;
      }
    ) lib.getExe pathOrStr
    // {
      description = "main program, path or command";
      descriptionClass = "conjunction";
    };

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

  # `null`/`[ ]`/`false` means "not set" and gets dropped, so callers can just
  # forward every option value and let unset bool flags default away.
  bfLines =
    entries:
    lib.filter (l: l != null) (
      lib.mapAttrsToList (
        k: v: if v == null || v == [ ] || v == false then null else "    ${k} = ${bfValue v}"
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

  # Stanza keys that are not finit settings
  # Nix-side identity, what becomes its own (sub-)block or is folded away and the deprecated spellings
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

  # options shared by ALL stanza types (service, task, run, tty).
  # `defaultRunlevel` is the one thing that differs between variants: "234" in the main module, "S" in the initrd one.
  mkBaseOpts = defaultRunlevel: {
    imports = [
      (lib.mkRenamedOptionModule [ "runlevels" ] [ "runlevel" ])
    ];

    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to enable this stanza.
        '';
      };

      settings = lib.mkOption {
        type = (pkgs.formats.keyValue { }).type;
        default = { };
        description = ''
          Freeform `finit` settings for this stanza, added as `key = value`
          entries to the generated block. Escape hatch for keys this module
          hasn't caught up with yet.

          See [upstream docs](https://finit-project.github.io/config/service-opts/).
        '';
      };

      conditions = lib.mkOption {
        type = with lib.types; coercedTo nonEmptyStr lib.singleton (listOf nonEmptyStr);
        apply = lib.unique;
        default = [ ];
        example = "pid/syslog";
        description = ''
          See [upstream documentation](https://finit-project.github.io/conditions/) for details.
        '';
      };

      runlevel = lib.mkOption {
        type = lib.types.str; # TODO: string matching 0-9S
        default = defaultRunlevel;
        description = ''
          See [upstream documentation](https://finit-project.github.io/runlevels/) for details.
        '';
      };
    };
  };

  # what every executable stanza shares: identity, what to run, and the two keys a tty block has no room for
  execOptsBase = {
    options = {
      # quoted, "if" is a Nix keyword: set as e.g. finit.services.foo."if" = ...
      "if" = lib.mkOption {
        type = with lib.types; nullOr nonEmptyStr;
        default = null;
        example = "!int/container";
        description = ''
          Conditionally load this stanza, evaluated once at the time the
          `.conf` file is read. Either the name of another service, e.g.
          `"udevd"`, or a condition, e.g. `"!int/container"`

          See [upstream documentation](https://finit-project.github.io/config/services/#conditional-execution) for details.
        '';
      };

      description = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        description = ''
          A human-readable description of this service, displayed by `initctl`.
        '';
      };

      name = lib.mkOption {
        type = lib.types.str; # TODO: limit name, no : allowed, only valid chars
        readOnly = true;
        description = ''
          The name of this stanza, derived from the attribute name.
        '';
      };

      id = lib.mkOption {
        type = with lib.types; nullOr str;
        readOnly = true;
        description = ''
          The instance identifier, derived from the attribute name if it contains an `@` character.
        '';
      };

      command = lib.mkOption {
        type = program;
        description = ''
          The command to execute.
        '';
      };

      tty = lib.mkOption {
        type = with lib.types; nullOr nonEmptyStr;
        default = null;
        example = "/dev/tty1";
        description = ''
          Give this stanza a controlling terminal on the given device, connecting its `stdin`, `stdout`, and
          `stderr` to the TTY. May be a device node like `/dev/ttyS0` or the special keyword `@console`.

          See [upstream documentation](https://finit-project.github.io/config/tty/) for additional details.
        '';
      };
    };
  };

  # run [PRIO] CMD <ARGS>
  runOpts = {
    options.priority = lib.mkOption {
      type = lib.types.int;
      default = 1000;
      description = ''
        Order of this `run` command in relation to the others. The semantics are the same as
        with `lib.mkOrder`. Smaller values have a greater priority.
      '';
    };
  };

  # tty [LVLS] <COND> DEV [BAUD] [noclear] [nowait] [nologin] [TERM]
  # tty [LVLS] <COND> CMD <ARGS> [noclear] [nowait]
  # TODO: assertions that make sure options make sense together
  ttyOpts =
    { name, config, ... }:
    {
      options = {
        id = lib.mkOption {
          type = with lib.types; nullOr nonEmptyStr;
          default = null;
          description = ''
            Explicit instance ID for the TTY. If not set, finit auto-derives it from the device name
            (e.g., `tty1` becomes `:1`, `ttyS0` becomes `:S0`).
          '';
        };

        device = lib.mkOption {
          type = with lib.types; nullOr nonEmptyStr;
          default = null;
          description = ''
            Embedded systems may want to enable automatic `device` by supplying the special `@console` device. This
            works regardless weather the system uses `ttyS0`, `ttyAMA0`, `ttyMXC0`, or anything else. `finit` figures
            it out by querying sysfs: `/sys/class/tty/console/active`.
          '';
        };

        command = lib.mkOption {
          type = lib.types.nullOr program;
          default = null;
          description = ''
            Specify an external `getty`, like `agetty` or the BusyBox `getty`.
          '';
        };

        baud = lib.mkOption {
          type = with lib.types; nullOr nonEmptyStr;
          default = null;
          description = ''
            Baud rate for serial TTYs.
          '';
        };

        term = lib.mkOption {
          type = with lib.types; nullOr nonEmptyStr;
          default = null;
          description = ''
            The `TERM` environment variable value for the TTY.
          '';
        };

        noclear = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Disables clearing the TTY after each session. Clearing the TTY when a user logs out is usually preferable.
          '';
        };

        nowait = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Disables the press `Enter to activate console` message before actually starting the `getty` program.
          '';
        };

        nologin = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Disables `getty` and `/bin/login`, and gives the user a `root` (login) shell on the given TTY `device`
            immediately. Needless to say, this is a rather insecure option, but can be very useful for developer
            builds, during board bringup, or similar.
          '';
        };

        rescue = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Start `sulogin` instead of a regular shell, requiring the root password. Useful for rescue/single-user mode.
          '';
        };

        notty = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            No device node mode. This is insecure and intended only for board bringup or testing scenarios.
          '';
        };
      };

      config = {
        device = lib.mkIf (config.command == null) (lib.mkDefault name);
      };
    };
in
{
  inherit
    pathOrStr
    program
    bfScalar
    bfValue
    bfLines
    bfIndent
    mkBlock
    mkTitle
    mkEntries
    mkBaseOpts
    execOptsBase
    runOpts
    ttyOpts
    ;
}
