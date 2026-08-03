{
  config,
  lib,
  ...
}:
let
  cfg = config.services.networkmanager;
in
{
  config = lib.mkIf cfg.enable {
    dinit.services.network-manager = {
      type = "process";
      command = "${cfg.package}/bin/NetworkManager -n";
      waits-for = [ "dbus" ];
      restart = true;
      smooth-recovery = true;
      targets = [ "network" ];
    };
  };
}
