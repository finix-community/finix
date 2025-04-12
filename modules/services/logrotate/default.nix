{ config, pkgs, lib, ... }:
let
  cfg = config.services.logrotate;

  rulesOpts = { name, ... }: {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };

      text = lib.mkOption {
        type = lib.types.lines;
        default = "";
      };
    };
  };

  configFile = cfg.rules
    |> lib.filterAttrs (_: v: v.enable)
    |> lib.mapAttrsToList (_: v: v.text)
    |> lib.concatStringsSep "\n"
    |> pkgs.writeText "logrotate.conf"
  ;
in
{
  options.services.logrotate = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.logrotate;
    };

    rules = lib.mkOption {
      type = with lib.types; attrsOf (submodule rulesOpts);
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    providers.scheduler.tasks = {
      logrotate = {
        interval = "hourly";
        command = "${cfg.package}/bin/logrotate ${configFile}";
      };
    };
  };
}
