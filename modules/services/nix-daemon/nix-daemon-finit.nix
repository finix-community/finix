{
  config,
  lib,
  ...
}:
let
  cfg = config.services.nix-daemon;
in
{
  config = lib.mkIf cfg.enable {
    finit.services.nix-daemon = {
      description = "nix daemon";
      conditions = "service/syslogd/ready";
      command = "${cfg.package}/bin/nix-daemon --daemon";
      nohup = true;

      environment.CURL_CA_BUNDLE = config.security.pki.caBundle;

      # https://github.com/NixOS/nix/blob/81884c36a381737a438ddc5decb658446074d064/misc/systemd/nix-daemon.service.in#L12-L13
      cgroup.settings."pids.max" = 1048576;
      rlimits.nofile = 1048576;
    };

    # TODO: add finit.services.restartTriggers option
    environment.etc."finit.d/nix-daemon.conf" =
      lib.mkIf (config.system.init == "finit" && config.finit.services.nix-daemon.enable)
        {
          text = lib.mkAfter ''

            # standard nixos trick to force a restart when something has changed
            # ${config.environment.etc."nix/nix.conf".source}
          '';
        };
  };
}
