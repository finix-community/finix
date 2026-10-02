# tty stanza is finicky and can cause some real problems if improper values are entered...
# strong type the entire thing in nix based on `tty_opts` in finit's conf.c
#
# https://finit-project.github.io/config/tty/
{
  lib,
  ...
}:
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
in
{
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

    runlevel = lib.mkOption {
      type = lib.types.strMatching "!?[0-9Ss]+";
      default = "234";
      description = ''
        See [upstream documentation](https://finit-project.github.io/runlevels/) for details.
      '';
    };

    conditions = lib.mkOption {
      type = with lib.types; coercedTo nonEmptyStr lib.singleton (listOf nonEmptyStr);
      apply = lib.unique;
      default = [ ];
      example = "service/elogind/ready";
      description = ''
        See [upstream documentation](https://finit-project.github.io/conditions/) for details.
      '';
    };

    device = lib.mkOption {
      type = with lib.types; nullOr nonEmptyStr;
      default = null;
      example = "/dev/tty1";
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

    notty = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        No device node mode. This is insecure and intended only for board bringup or testing scenarios.
      '';
    };

    rescue = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Start `sulogin` instead of a regular shell, requiring the root password. Useful for rescue/single-user mode.
      '';
    };
  };
}
