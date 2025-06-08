{ config, pkgs, lib, ... }:
let
  cfg = config.boot;

  # Sort and join the command-line of PID 1.
  pid1Argv =
    (lib.textClosureList cfg.init.pid1Argv (builtins.attrNames cfg.init.pid1Argv))
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

    pid1Argv = lib.mkOption {
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
  };

  config = {

    boot.kernelParams = [
      "init=${cfg.init.script}"
    ];

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
