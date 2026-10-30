{
  config,
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

  # Pattern to match an interval type
  range = n: "${n}(-${n})?";
  step = n: "(/${n})?";
  list = item: "(${item}(,${item})*)";
  field = n: list ''(\*|${range n})${step n}'';

  expr = builtins.concatStringsSep " " [
    (field "([0-5]?[0-9])") # minute
    (field "([01]?[0-9]|2[0-3])") # hour
    (field "(0?[1-9]|[12][0-9]|3[01])") # day
    (field "(0?[1-9]|1[0-2])") # month
    (field "[0-7]") # weekday
  ];
  macro = "(hourly|daily|weekly|monthly|yearly)";

  intervalType = lib.types.strMatching "(${macro}|${expr})" // {
    description = "hourly, daily, weekly, monthly, yearly, or a cron-like expression";
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
      type = lib.types.enum [ "none" ];
      default = "none";
      description = ''
        The selected module which should implement functionality for the {option}`providers.scheduler` contract.
      '';
    };

    tasks = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {

            interval = lib.mkOption {
              type = intervalType;
              example = "15 * * * *";
              description = ''
                The interval at which this task should run its specified {option}`command`.

                Accepts a cron-like expression or one of the following macro values: `hourly`, `daily`, `weekly`, `monthly`, or `yearly`.

                A cron-like expression is of the following format:
                  `minute hour day month weekday`
                  
                The fields have the constraints:
                  minute  0-59
                  hour    0-23
                  day     1-31
                  month   1-12
                  weekday 0-7 (0 or 7 is Sunday) 
                And can be specified with a combination of:
                    x: match x 
                  '*': every value
                  ',': list
                  '-': range
                  '/': step

                If one of the macro values is provided then the underlying `scheduler` implementation
                will use its features to decide when best to run.
              '';
            };

            command = lib.mkOption {
              type = program;
              description = ''
                The command this task should execute at specified {option}`interval`s.
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
        }
      );
      default = { };
      description = ''
        A set of tasks which are to be run at specified intervals.
      '';
    };
  };

  config.warnings =
    lib.optionals
      (config.providers.scheduler.tasks != { } && config.providers.scheduler.backend == "none")
      [
        ''
          no scheduler provider backend has been enabled, yet the following scheduled tasks are defined:
          ${lib.concatStringsSep ", " (lib.attrNames config.providers.scheduler.tasks)}
          select a backend implementation to use scheduled tasks
        ''
      ];
}
