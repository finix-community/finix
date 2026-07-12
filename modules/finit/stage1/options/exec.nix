{ lib, program }:
{ name, ... }:
{
  options = {
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

  config = {
    name = lib.head (lib.splitString "@" name);
    id = if lib.hasInfix "@" name then lib.elemAt (lib.splitString "@" name) 1 else null;
  };
}
