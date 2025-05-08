{ lib, ... }:
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
  options.providers.scheduler = {
    supportedFeatures = {
      user = lib.mkOption {
        type = lib.types.bool;
        description = ''
          Whether the selected {option}`providers.scheduler` implementation supports running tasks as
          a specified user.
        '';
      };
    };

    backend = lib.mkOption {
      type = lib.types.enum [ ];
      description = ''
        The selected module which should implement functionality for the {option}`providers.scheduler` contract.
      '';
    };

    tasks = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          command = lib.mkOption {
            type = program;
            description = ''
              The command this task should execute at specified {option}`interval`s.
            '';
          };

          interval = lib.mkOption {
            type = lib.types.str;
            example = "15 * * * *";
            description = ''
              The interval at which this task should run its specified {option}`command`. Accepts either a
              standard {manpage}`crontab(5)` expression or one of: `hourly`, `daily`, `weekly`, `monthly`, or `yearly`.

              If a standard {manpage}`crontab(5)` expression is provided this value will be passed directly
              to the `scheduler` implementation and execute exactly as specified.

              If one of the special values, `hourly`, `daily`, `monthly`, `weekly`, or `yearly`, is provided then the
              underlying `scheduler` implementation will use its features to decide when best to run.
            '';
          };

          user = lib.mkOption {
            type = with lib.types; nullOr str;
            default = null;
            description = ''
              The user this task should run as, subject to {option}`provider.scheduler` implementation
              capabilities. See {option}`providers.scheduler.supportedFeatures` and your selected backend
              implementation for additional details.
            '';
          };
        };
      });
      default = { };
      description = ''
        A set of tasks which are to be run at specified intervals.
      '';
    };
  };
}
