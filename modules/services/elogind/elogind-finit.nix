{
  config,
  lib,
  ...
}:
let
  cfg = config.services.elogind;
in
{
  options.finit.ttys = lib.mkOption {
    type =
      with lib.types;
      attrsOf (submodule {
        config = lib.mkIf cfg.enable {
          conditions = "service/elogind/ready";
        };
      });
  };

  config = lib.mkIf cfg.enable {
    finit.services.elogind = {
      description = "login manager";
      conditions = "service/dbus/ready";
      command = "${cfg.package}/libexec/elogind";
    };
  };
}
