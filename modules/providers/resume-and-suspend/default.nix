{ lib, ... }:
{
  options.providers.resumeAndSuspend = {
    backend = lib.mkOption {
      type = lib.types.enum [ ];
      description = ''
        The selected module which should implement functionality for the {option}`providers.resumeAndSuspend` contract.
      '';
    };

    hooks = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = ''
                Whether this hook should be executed on the given `event`.
              '';
            };

            event = lib.mkOption {
              type = lib.types.enum [
                "suspend"
                "resume"
              ];
              description = ''
                The event type.
              '';
            };

            action = lib.mkOption {
              type = lib.types.lines;
              default = "";
              description = ''
                Shell commands to execute when the `event` is triggered.
              '';
            };

            priority = lib.mkOption {
              type = lib.types.ints.between 0 9999;
              default = 1000;
              description = ''
                Order of this hook in relation to the others. The semantics are
                the same as with `lib.mkOrder`. Smaller values are inserted first.
              '';
            };
          };
        }
      );
      default = { };
      description = ''
        A set of hooks which are to be run on system _suspend_ or _resume_.
      '';
    };
  };
}
