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
  options.providers.privileges = {
    supportedFeatures = {
      # TODO:
    };

    backend = lib.mkOption {
      type = lib.types.enum [ ];
      description = ''
        The selected module which should implement functionality for the {option}`providers.privileges` contract.
      '';
    };

    command = lib.mkOption {
      type = program;
      example = "/run/wrappers/bin/sudo";
      description = ''
        The command to be used by modules requiring privilege escalation.
      '';
    };

    rules = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          command = lib.mkOption {
            type = program;
            description = ''
              The command the user or group members are allowed to run.

              ::: {.note}
              It is best practice to specify absolute paths.
              :::
            '';
          };

          args = lib.mkOption {
            type = with lib.types; listOf str;
            default = [ ];
            description = ''
              Arguments that must be provided to the command. When
              empty, the command must be run without any arguments.
            '';
          };

          users = lib.mkOption {
            type = with lib.types; listOf nonEmptyStr;
            default = [ ];
            description = ''
              The users that are able to run this command.
            '';
          };

          groups = lib.mkOption {
            type = with lib.types; listOf nonEmptyStr;
            default = [ ];
            description = ''
              The groups that are able to run this command.
            '';
          };

          requirePassword = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Whether the user is required to enter a password.
            '';
          };

          runAs = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "root";
            description = ''
              The user the command is allowed to run as, or `"*"` for allowing the command to run as any user.
            '';
          };
        };
      });
      default = [ ];
      description = ''
        A list of rules which provide a way to temporarily elevate the privileges of a command for a given user or group.
      '';
    };
  };
}
