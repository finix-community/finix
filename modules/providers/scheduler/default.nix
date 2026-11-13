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
in
{
  options.providers.scheduler = {
    supportedFeatures = {
      user = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether the selected {option}`providers.scheduler` implementation supports running tasks as
          a specified user.
        '';
      };

      persistent = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether the selected {option}`providers.scheduler` implementation supports running the tasks when
          the schedule was missed.
        '';
      };

      randomDelay = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether the selected {option}`providers.scheduler` implementation supports randomly delaying tasks
          by an amount determined by that implementation.
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
              type = lib.types.enum [
                "minutely"
                "hourly"
                "daily"
                "monthly"
                "weekly"
              ];
              description = ''
                The interval at which this task should run.

                The underlying {option}`providers.scheduler` implementation uses its scheduling features
                to choose an appropriate time to run within that interval.
              '';
            };

            persistent = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = ''
                If the task should be run, even if the schedule window was missed.
              '';
            };

            randomDelay = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = ''
                Whether to randomly delay this task. The underlying {option}`providers.scheduler`
                implementation determines the amount of delay.
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
