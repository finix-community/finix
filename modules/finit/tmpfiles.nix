{
  config,
  lib,
  ...
}:
{
  options.finit.tmpfiles.rules = lib.mkOption {
    type = with lib.types; listOf str;
    default = [ ];
    example = [ "d /tmp 1777 root root 10d" ];
    description = ''
      Rules for creation, deletion and cleaning of volatile and temporary files
      automatically. See {manpage}`tmpfiles.d(5)` for the exact format.
    '';
  };

  config = {
    environment.etc."tmpfiles.d/finix.conf" = lib.mkIf (config.finit.enable || config.dinit.enable) {
      text = ''
        # This file is created automatically and should not be modified.
        # Please change the option ‘finit.tmpfiles.rules’ instead.

        ${lib.concatStringsSep "\n" config.finit.tmpfiles.rules}
      '';
    };

    finit = lib.mkIf config.finit.enable {
      # needed for finit tmpfiles Z implementation: pkgs.policycoreutils
      # TODO: make this an optional dependency, fixup Z behaviour in general
      tasks.tmpfiles-setup = {
        command = "${config.finit.package}/libexec/finit/tmpfiles --create";
      };
    };

    providers.scheduler.tasks = lib.mkIf config.finit.enable {
      tmpfiles-clean = {
        interval = "daily";
        command = "${config.finit.package}/libexec/finit/tmpfiles --clean";
      };
    };

    environment.etc."finit.d/tmpfiles-setup.conf" =
      lib.mkIf (config.finit.enable && config.finit.tasks.tmpfiles-setup.enable)
        {
          text = lib.mkAfter ''

            # force a restart on configuration change
            # ${config.environment.etc."tmpfiles.d/finix.conf".source}
          '';
        };

    dinit.services.tmpfiles-setup = lib.mkIf config.dinit.enable {
      type = "scripted";
      command = "${config.finit.package}/libexec/finit/tmpfiles --create";
      waits-for = [ "mount-fstab" ];
      targets = [ "filesystem" ];
    };
  };
}
