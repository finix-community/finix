{
  pkgs,
  config,
  lib,
  ...
}:
let
  inherit (import ./common.nix { inherit lib config; }) cfg;
in
{
  config = lib.mkIf cfg.enable {
    services.udev.packages = lib.optionals cfg.power.runtime.enable [
      (pkgs.writeTextDir "lib/udev/rules.d/80-nvidia-pm.rules" ''
        ACTION=="bind",   SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="auto"
        ACTION=="bind",   SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="auto"
        ACTION=="bind",   SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", TEST=="power/control", ATTR{power/control}="auto"
        ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", TEST=="power/control", ATTR{power/control}="on"
        ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030200", TEST=="power/control", ATTR{power/control}="on"
        ACTION=="unbind", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", TEST=="power/control", ATTR{power/control}="on"
      '')
    ];

    providers.resumeAndSuspend.hooks =
      lib.optionalAttrs (cfg.power.suspend.enable && cfg.power.suspend.notifier == "userspace")
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
            priority = 900; # run after other resume hooks
          };
        };
  };
}
