{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.logrotate;

  rulesOpts =
    { name, ... }:
    {
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

  configFile = pkgs.writeText "logrotate.conf" (
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (_: v: v.text) (lib.filterAttrs (_: v: v.enable) cfg.rules)
    )
  );
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
