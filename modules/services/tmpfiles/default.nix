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

    environment.etc =
      let
        etcTree = lib.mapAttrs' (k: v: {
          name = "tmpfiles.d/${k}.conf";
          value.text = ''
            # This file is created automatically and should not be modified.
            # Please change the option ‘services.tmpfiles.${k}.rules’ instead.

            ${lib.concatStringsSep "\n" v.rules}
          '';
        }) (lib.filterAttrs (_: v: v.enable) config.services.tmpfiles);

        reload = {
          "finit.d/tmpfiles-setup.conf".text = lib.mkAfter ''

            # force a restart on configuration change
            ${lib.concatMapAttrsStringSep "\n" (k: v: "# " + config.environment.etc."tmpfiles.d/${k}.conf".source) (lib.filterAttrs (_: v: v.enable) config.services.tmpfiles)}
          '';
        };
      in
        lib.mkMerge [ etcTree reload ];

    finit.tasks.tmpfiles-setup.command = "${config.finit.package}/libexec/finit/tmpfiles --create";

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
