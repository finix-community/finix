{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.dbus;
in
{
  config = lib.mkIf cfg.enable {
    finit.services.dbus = {
      description = "d-bus message bus daemon";
      runlevels = "S123456789";
      conditions = "service/syslogd/ready";
      command = "${cfg.package}/bin/dbus-daemon --nofork --system --syslog-only";
      notify = "systemd";
      cgroup.name = "system";

      pre = pkgs.writeShellScript "dbus-pre.sh" "${cfg.package}/bin/dbus-uuidgen --ensure";
      environment = {
        DBUS_VERBOSE = lib.mkIf cfg.debug 1;
      };
    };

    # TODO: add finit.services.reloadTriggers option
    environment.etc."finit.d/dbus.conf" =
      lib.mkIf (config.system.init == "finit" && config.finit.services.dbus.enable)
        {
          text = lib.mkAfter ''

            # reload trigger
            # ${config.environment.etc."dbus-1".source}
          '';
        };
  };
}
