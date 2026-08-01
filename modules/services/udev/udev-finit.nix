{
  config,
  lib,
  ...
}:
let
  cfg = config.services.udev;
in
{
  config = lib.mkIf (config.system.init == "finit" && cfg.enable) {
    # adapted from https://github.com/troglobit/finit/blob/master/system/10-hotplug.conf.in
    finit.services.udevd = {
      description = "device event daemon (${cfg.package.pname})";
      runlevels = "S12345789";
      command = "${cfg.package}/bin/udevd --ready-notify=%n" + lib.optionalString cfg.debug " -D";
      notify = "s6";
      pid = "udevd";
      log = true;
      nohup = true;
      cgroup.name = "system";
    };

    # Wait for udevd to start, then trigger coldplug events and module loading.
    # The last `settle` call waits for it to finalize processing all uevents.
    finit.run =
      let
        defaults = {
          runlevels = "S";
          conditions = "service/udevd/ready";
          log = true;
          cgroup.name = "init";
          extraConfig = "nowarn";
          priority = 1;
        };
      in
      {
        "udevadm@1" = defaults // {
          description = "";
          command = "${cfg.package}/bin/udevadm settle -t 0";
        };
        "udevadm@2" = defaults // {
          description = "";
          command = "${cfg.package}/bin/udevadm control --reload";
        };
        "udevadm@3" = defaults // {
          description = "requesting device events";
          command = "${cfg.package}/bin/udevadm trigger -c add -t devices";
        };
        "udevadm@4" = defaults // {
          description = "requesting subsystem events";
          command = "${cfg.package}/bin/udevadm trigger -c add -t subsystems";
        };
        "udevadm@5" = defaults // {
          description = "waiting for udev to finish";
          command = "${cfg.package}/bin/udevadm settle -t 30";
        };
      };
  };
}
