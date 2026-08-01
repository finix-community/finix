{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.dbus;
in
{
  config = lib.mkIf (config.system.init == "dinit" && cfg.enable) {
    dinit.services.dbus = {
      type = "process";
      command = toString (
        pkgs.writeShellScript "dbus-dinit-start" ''
          ${cfg.package}/bin/dbus-uuidgen --ensure
          exec ${cfg.package}/bin/dbus-daemon --nofork --system --syslog-only
        ''
      );
      waits-for =
        lib.optional (config.services ? sysklogd && config.services.sysklogd.enable) "syslogd"
        ++ [ "tmpfiles-setup" ];
      restart = true;
      smooth-recovery = true;
      targets = [ "local" ];

      environment = lib.optionalAttrs cfg.debug {
        DBUS_VERBOSE = "1";
      };
    };

  };
}
