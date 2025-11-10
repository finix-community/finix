{
  lib,
  config,
  pkgs,
  ...
}:

{
  config = {
    # Syslog compatibility daemon.
    synit.core.daemons.syslog = {
      argv = [
        (lib.getExe' pkgs.s6 "s6-socklog")
        "-d"
        "3"
      ];
      readyOnNotify = 3;
    };
  };
}
