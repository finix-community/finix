{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.hardware.nvidia;
in
{
  options.hardware.nvidia.reduceTearing = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Reduce screen tearing on displays connected directly to the NVIDIA GPU by
      enabling its full composition pipeline. This sets the
      `ForceFullCompositionPipeline` metamode and, alongside it, disables
      indirect GLX and enables triple buffering on the X screen.

      Trade-offs: it forces the screen to be redrawn even when nothing changed,
      which can reduce the performance of OpenGL/fullscreen applications (and
      has been reported to cause issues with WebGL), and it increases the time
      the driver takes to clock down after load.

      See <https://wiki.archlinux.org/title/NVIDIA/Troubleshooting#Avoid_screen_tearing_on_Xorg>.
    '';
  };

  config = lib.mkIf (cfg.enable && config.programs.xorg.enable) {
    finit.tmpfiles.rules = [
      # Remove the following log message:
      #    (WW) NVIDIA: Failed to bind sideband socket to
      #    (WW) NVIDIA:     '/var/run/nvidia-xdriver-b4f69129' Permission denied
      #
      # https://bbs.archlinux.org/viewtopic.php?pid=1909115#p1909115
      "d /run/nvidia-xdriver 0770 root users"
    ];

    environment.etc."X11/xorg.conf.d/00-nvidia.conf".source = pkgs.writeText "00-nvidia.conf" ''
      Section "Device"
        Identifier "Device-nvidia[0]"
        Driver "nvidia"
        Option "SidebandSocketPath" "/run/nvidia-xdriver/"
      EndSection

      Section "Screen"
        Identifier "Screen-nvidia[0]"
        Device "Device-nvidia[0]"
        Option "RandRRotation" "on"
        ${lib.optionalString cfg.reduceTearing ''
          Option "metamodes" "nvidia-auto-select +0+0 {ForceFullCompositionPipeline=On}"
          Option "AllowIndirectGLXProtocol" "off"
          Option "TripleBuffer" "on"
        ''}
      EndSection
    '';

    programs.xorg.modules = [ cfg.package.bin ];
  };
}
