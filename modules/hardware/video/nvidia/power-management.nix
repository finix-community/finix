{
  config,
  lib,
  pkgs,
  ...
}:
let
  common = import ./common.nix { inherit config lib pkgs; };
  inherit (common) cfg;
in
{
  config = lib.mkIf cfg.enable {
    providers.resumeAndSuspend.hooks =
      lib.optionalAttrs (cfg.powerManagement.enable && !cfg.powerManagement.kernelSuspendNotifier)
        {
          nvidia-suspend = {
            event = "suspend";
            action = "PATH=${pkgs.kbd}/bin:$PATH ${cfg.package.out}/bin/nvidia-sleep.sh 'suspend'";
            priority = 100;
          };
          nvidia-hibernate = {
            event = "hibernate";
            action = "${cfg.package.out}/bin/nvidia-sleep.sh 'hibernate'";
            priority = 100;
          };
          nvidia-resume = {
            event = "resume";
            action = "${cfg.package.out}/bin/nvidia-sleep.sh 'resume'";
            priority = 900;
          };
        };
  };
}
