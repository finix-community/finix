{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = {
    # Mount everything using the ordering in
    # /etc/fstab and retry until it completes.
    synit.core.daemons.mount-all = {
      argv = lib.quoteExecline [
        "if"
        [
          "mount"
          "--verbose"
          "--all"
        ]
        "redirfd"
        "-w"
        "1"
        "/run/synit/config/state/suid-sgid-wrappers.pr"
        "s6-echo"
        "<service-state <daemon mount-all> ready>"
      ];
      path = [ pkgs.util-linux.mount ];
      readyOnStart = false;
      restart = "on-error";
      logging.enable = false;
    };
  };
}
