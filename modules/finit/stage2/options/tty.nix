{ lib, program }:
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

    command = lib.mkOption {
      type = lib.types.nullOr program;
      default = null;
      description = ''
        Specify an external `getty`, like `agetty` or the BusyBox `getty`.
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
  };

  config = {
    device = lib.mkIf (config.command == null) (lib.mkDefault name);
  };
}
