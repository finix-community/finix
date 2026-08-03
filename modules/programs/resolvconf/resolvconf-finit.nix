{
  config,
  lib,
  ...
}:
let
  cfg = config.programs.resolvconf;
in
{
  config = lib.mkIf cfg.enable {
    finit.tasks.resolvconf = {
      command = "${lib.getExe cfg.package} -u";
      remain = true;
    };

    # TODO: add finit.tasks.reloadTriggers option
    environment.etc."finit.d/resolvconf.conf" = lib.mkIf (config.finit.tasks.resolvconf.enable) {
      text = lib.mkAfter ''

        # force a restart on configuration change
        # ${config.environment.etc."resolvconf.conf".source}
      '';
    };
  };
}
