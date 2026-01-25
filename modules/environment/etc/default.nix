{
  config,
  pkgs,
  lib,
  ...
}:
let
  buildEtc =
    pkgs.runCommandLocal "etc"
      {
        # This is needed for the systemd module
        passthru.targets = map (x: x.target) etc';
      }
      /* sh */ ''
        set -euo pipefail

        makeEtcEntry() {
          src="$1"
          target="$2"
          mode="$3"
          user="$4"
          group="$5"

          if [[ "$src" = *'*'* ]]; then
            # If the source name contains '*', perform globbing.
            mkdir -p "$out/etc/$target"
            for fn in $src; do
                ln -s "$fn" "$out/etc/$target/"
            done
          else

            mkdir -p "$out/etc/$(dirname "$target")"
            if ! [ -e "$out/etc/$target" ]; then
              ln -s "$src" "$out/etc/$target"
            else
              echo "duplicate entry $target -> $src"
              if [ "$(readlink "$out/etc/$target")" != "$src" ]; then
                echo "mismatched duplicate entry $(readlink "$out/etc/$target") <-> $src"
                ret=1

                continue
              fi
            fi

            if [ "$mode" != symlink ]; then
              echo "$mode" > "$out/etc/$target.mode"
              echo "$user" > "$out/etc/$target.uid"
              echo "$group" > "$out/etc/$target.gid"
            fi
          fi
        }

        mkdir -p "$out/etc"
        ${lib.concatMapStringsSep "\n" (
          etcEntry:
          lib.escapeShellArgs [
            "makeEtcEntry"
            # Force local source paths to be added to the store
            "${etcEntry.source}"
            etcEntry.target
            etcEntry.mode
            etcEntry.user
            etcEntry.group
          ]
        ) etc'}
      '';

  etc' = lib.filter (f: f.enable) (lib.attrValues config.environment.etc);
in
{
  imports = [ ./options.nix ];

  config = {
    assertions = [
      {
        assertion = config.system.activation.enable;
        message = "this etc implementation requires an activatable system";
      }
    ];

    environment.etc.mtab.source = "/proc/mounts";

    # TODO: create an alternative implementation with... https://github.com/Gerg-L/linker
    system.activation.scripts.etc = lib.stringAfter [ "users" ] ''
      echo "setting up /etc..."
      ${pkgs.perl.withPackages (p: [ p.FileSlurp ])}/bin/perl ${./setup-etc.pl} ${buildEtc}/etc
    '';

    system.activation.scripts.shebangCompatibility = ''
      mkdir -p -m 0755 /usr/bin /bin

      # Create /usr/bin/env for shebangs.
      ln -sfn ${pkgs.coreutils}/bin/env /usr/bin/env

      # Create the required /bin/sh symlink; otherwise lots of things
      # (notably the system() function) won't work.
      ln -sfn "${pkgs.bashInteractive}/bin/sh" /bin/sh
    '';
  };
}
