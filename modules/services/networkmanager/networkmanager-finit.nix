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
    finit.services.network-manager = {
      description = "network manager service";
      conditions = "service/dbus/ready";
      command = "${cfg.package}/bin/NetworkManager -n";
    };

    # TODO: add finit.services.reloadTriggers option
    environment.etc."finit.d/network-manager.conf" =
      lib.mkIf (config.finit.services.network-manager.enable)
        {
          text = lib.mkAfter ''

            # reload trigger
            # ${config.environment.etc."NetworkManager/conf.d/00-nixos.conf".source}
          '';
        };
  };
}
