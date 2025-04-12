{ pkgs, config, lib, ... }:
let
  tmpfilesOpts = {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };

      rules = lib.mkOption {
        type = with lib.types; listOf str;
        default = [];
        example = [ "d /tmp 1777 root root 10d" ];
        description = ''
          Rules for creation, deletion and cleaning of volatile and temporary files
          automatically. See {manpage}`tmpfiles.d(5)` for the exact format.
        '';
      };
    };
  };
in
{
  options.services.tmpfiles = lib.mkOption {
    type = with lib.types; attrsOf (submodule tmpfilesOpts);
    default = { };
  };

  config = {
    # TODO: improve finit so tmpfiles can cleanup aged files
    # TODO: improve finit so it can call tmpfiles as a service once in a while?

    environment.etc = lib.mapAttrs' (k: v: {
      name = "tmpfiles.d/${k}.conf";
      value.text = ''
        # This file is created automatically and should not be modified.
        # Please change the option ‘services.tmpfiles.${k}.rules’ instead.

        ${lib.concatStringsSep "\n" v.rules}
      '';
    }) (lib.filterAttrs (_: v: v.enable) config.services.tmpfiles);

    # TODO: run once a day
    # providers.scheduler.tasks = {
    #   tmpfiles-clean = {
    #     interval = "daily";
    #     command = "${config.finit.package}/libexec/tmpfiles --clean";
    #   };
    # };

    # needed for finit tmpfiles implementation: pkgs.policycoreutils
  };
}
