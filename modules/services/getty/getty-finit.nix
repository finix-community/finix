{
  config,
  lib,
  ...
}:
let
  cfg = config.services.getty;
in
{
  config = lib.mkIf cfg.enable {
    finit.ttys = lib.genAttrs cfg.ttys (
      device:
      {
        description = "getty on ${device}";
        nowait = true;
      }
      // lib.optionalAttrs (cfg.package != null) {
        command = "${lib.getExe cfg.package} ${lib.escapeShellArgs cfg.extraArgs} ${device}";
      }
    );
  };
}
