{
  config,
  lib,
  options,
  ...
}:
let
  cfg = config.finit.tmpfiles;
in
{
  options.finit.tmpfiles = {
    rules = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      example = [ "d /tmp 1777 root root 10d" ];
      description = ''
        Rules for creation, deletion and cleaning of volatile and temporary files
        automatically. See {manpage}`tmpfiles.d(5)` for the exact format.
      '';
    };

    clean = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable automatic cleaning of temporary files.

          :::{.note}
          You must have a scheduler backend configured with
          `providers.scheduler.backend` to utilize this option.
          :::
        '';
      };

      interval = lib.mkOption {
        inherit ((options.providers.scheduler.tasks.type.getSubOptions [ ]).interval)
          type
          description
          example
          ;
        default = "daily";
      };

    };
  };

  config = {
    environment.etc."tmpfiles.d/finix.conf".text = ''
      # This file is created automatically and should not be modified.
      # Please change the option ‘finit.tmpfiles.rules’ instead.

      ${lib.concatStringsSep "\n" config.finit.tmpfiles.rules}
    '';

    finit.tasks.tmpfiles-setup = {
      command = "${config.finit.package}/libexec/finit/tmpfiles --create";
      reload-triggers = [
        config.environment.etc."tmpfiles.d/finix.conf".source
      ];
    };

    providers.scheduler.tasks = lib.mkIf cfg.clean.enable {
      tmpfiles-clean = {
        interval = cfg.clean.interval;
        command = "${config.finit.package}/libexec/finit/tmpfiles --clean";
      };
    };

    # needed for finit tmpfiles Z implementation: pkgs.policycoreutils
    # TODO: make this an optional dependency, fixup Z behaviour in general
  };
}
