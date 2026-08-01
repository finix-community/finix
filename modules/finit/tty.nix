# tty stanza is finicky and can cause some real problems if improper values are entered...
# strong type the entire thing in nix based on `tty_opts` in finit's conf.c
{
  name,
  lib,
  ...
}:
{
  imports = [
    (lib.mkRenamedOptionModule [ "runlevels" ] [ "runlevel" ])
  ];

  options = {
    # finix extensions
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to enable this stanza.
      '';
    };

    name = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      description = ''
        The name of this stanza, derived from the attribute name.
      '';
    };

    id = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      readOnly = true;
      description = ''
        The instance identifier, derived from the attribute name if it contains an `@` character.
      '';
    };

    reload-triggers = lib.mkOption {
      type = with lib.types; listOf (either str path);
      default = [ ];
      description = ''
        An arbitrary list of items such as derivations. If any item in the list
        changes between reconfigurations, the service will be reloaded or restarted
        if reloads are not supported.
      '';
    };

    # finit `tty_opts` keys
    runlevel = lib.mkOption {
      type = with lib.types; nullOr (strMatching "!?[0-9Ss]+");
      default = null;
      description = ''
        See [upstream documentation](https://finit-project.github.io/runlevels/) for details.
      '';
    };

    conditions = lib.mkOption {
      type = with lib.types; nullOr (coercedTo str lib.singleton (listOf str));
      default = null;
      example = "service/elogind/ready";
      description = ''
        See [upstream documentation](https://finit-project.github.io/conditions/) for details.
      '';
    };

    device = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      example = "/dev/tty1";
      description = ''
        Embedded systems may want to enable automatic `device` by supplying the special `@console` device. This
        works regardless weather the system uses `ttyS0`, `ttyAMA0`, `ttyMXC0`, or anything else. `finit` figures
        it out by querying sysfs: `/sys/class/tty/console/active`.
      '';
    };

    command = lib.mkOption {
      type = with lib.types; nullOr (coercedTo path toString str);
      default = null;
      description = ''
        Specify an external `getty`, like `agetty` or the BusyBox `getty`.
      '';
    };

    baud = lib.mkOption {
      type = with lib.types; nullOr int;
      default = null;
      description = ''
        Baud rate for serial TTYs.
      '';
    };

    term = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = ''
        The `TERM` environment variable value for the TTY.
      '';
    };

    noclear = lib.mkOption {
      type = with lib.types; nullOr bool;
      default = null;
      description = ''
        Disables clearing the TTY after each session. Clearing the TTY when a user logs out is usually preferable.
      '';
    };

    nowait = lib.mkOption {
      type = with lib.types; nullOr bool;
      default = null;
      description = ''
        Disables the press `Enter to activate console` message before actually starting the `getty` program.
      '';
    };

    nologin = lib.mkOption {
      type = with lib.types; nullOr bool;
      default = null;
      description = ''
        Disables `getty` and `/bin/login`, and gives the user a `root` (login) shell on the given TTY `device`
        immediately. Needless to say, this is a rather insecure option, but can be very useful for developer
        builds, during board bringup, or similar.
      '';
    };

    notty = lib.mkOption {
      type = with lib.types; nullOr bool;
      default = null;
      description = ''
        No device node mode. This is insecure and intended only for board bringup or testing scenarios.
      '';
    };

    rescue = lib.mkOption {
      type = with lib.types; nullOr bool;
      default = null;
      description = ''
        Start `sulogin` instead of a regular shell, requiring the root password. Useful for rescue/single-user mode.
      '';
    };
  };

  config =
    let
      parts = lib.splitString "@" name;
    in
    {
      name = lib.head parts;
      id =
        if lib.hasSuffix "@" name then
          "%i"
        else if lib.hasInfix "@" name then
          lib.elemAt parts 1
        else
          null;
    };
}
