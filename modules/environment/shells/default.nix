{
  config,
  pkgs,
  lib,
  ...
}:
let
  utils = import (pkgs.path + "/nixos/lib/utils.nix") { inherit config pkgs lib; };
in
{
  options.environment.shells = lib.mkOption {
    type = with lib.types; listOf (either shellPackage path);
    default = [ ];
  };

  config = {
    environment.etc.shells.text = ''
      ${lib.concatStringsSep "\n" (map utils.toShellPath config.environment.shells)}
      /bin/sh
    '';

    environment.etc.profile.text = ''
      # /etc/profile: system-wide initialisation for POSIX login shells

      # Source the drop-in scripts.
      if [ -d /etc/profile.d ]; then
        for i in /etc/profile.d/*.sh; do
          [ -r "$i" ] && . "$i"
        done
        unset i
      fi
    '';
  };
}
