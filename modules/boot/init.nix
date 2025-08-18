{ config, pkgs, lib, ... }:
let
  cfg = config.boot.init;

  # Sort and join the command-line of PID 1.
  pid1Argv =
    (lib.textClosureList cfg.pid1.argv (builtins.attrNames cfg.pid1.argv))
    |> lib.flatten
    |> lib.escapeShellArgs;
in
{
  # TODO: something not quite sitting right with me here
  options.boot.init = {
    script = lib.mkOption {
      type = lib.types.path;
      readOnly = true;
    };

    pid1 = {
      argv = lib.mkOption {
        description = ''
          The PID 1 command line as a closure-list.
        '';
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              deps = lib.mkOption {
                type = with lib.types; listOf str;
                default = [ ];
                description = "List of argument groups that must preceded this one.";
              };
              text = lib.mkOption {
                type = with lib.types; uniq (either str (listOf (either str path)));
                description = "Group of arguments for the pid1 command-line.";
              };
            };
          }
        );
      };
      env = lib.mkOption {
        description = ''
          Environment variables to start PID 1 with.
        '';
        type = with lib.types; attrsOf str;
        default = { };
      };
    };
  };

  config = {

    # Set the environment via argv.
    boot.init.pid1.argv.env.text = cfg.pid1.env
      |> builtins.attrNames
      |> lib.concatMap (key: [ "${pkgs.execline}/bin/export" key cfg.pid1.env.${key} ]);

    boot.init.script = pkgs.writeScript "init" ''
      #!${pkgs.runtimeShell}

      systemConfig='@systemConfig@'

      echo
      echo "[1;32m<<< finix - stage 2 >>>[0m"
      echo

      echo "running activation script..."
      $systemConfig/activate

      # record the boot configuration.
      ${pkgs.coreutils}/bin/ln -sfn "$systemConfig" /run/booted-system

      exec ${pid1Argv} $@
    '';
  };
}
