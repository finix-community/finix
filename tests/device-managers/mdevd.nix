let
  common = import ./common.nix;
in
common {
  backend = {
    name = "mdevd";
    serviceName = "mdevd";
    readyCondition = "service/mdevd/ready";
    coldplugCondition = "run/coldplug/success";
    configCheck = "-N -f /etc/mdev.conf";
    module =
      { eventScript, ... }:
      {
        services.mdevd.enable = true;
        services.mdevd.coldplugRules = ''
          -SUBSYSTEM=block;vd[a-z]+ 0:0 660 */etc/device-manager-test-event
          -SUBSYSTEM=block;loop[0-9]+ 0:0 660 */etc/device-manager-test-event
        '';
        services.mdevd.hotplugRules = ''
          -SUBSYSTEM=block;vd[a-z]+ 0:0 660 */etc/device-manager-test-event
          -SUBSYSTEM=block;loop[0-9]+ 0:0 660 */etc/device-manager-test-event
        '';
        services.mdevd.nlgroups = 4;
      };
    diskGid = 6;
  };
}
