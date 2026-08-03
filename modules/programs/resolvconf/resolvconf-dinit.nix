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
    dinit.services.resolvconf = {
      type = "scripted";
      command = "${lib.getExe cfg.package} -u";
      targets = [ "network" ];
    };
  };
}
