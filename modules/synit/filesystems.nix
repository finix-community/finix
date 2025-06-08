{ config, pkgs, ... }:

{
  config = {
    # Mount everything using the ordering in
    # /etc/fstab and retry until it completes.
    synit.core.daemons.mount-all = {
      argv = [ "${pkgs.util-linux.mount}/bin/mount" "--verbose" "--all" ];
      restart = "on-error";
      logging.enable = false;
    };
  };
}
