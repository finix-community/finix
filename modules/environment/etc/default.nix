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
  options.environment.etc = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (
        {
          name,
          config,
          options,
          ...
        }:
        {
          options = {
            enable = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = ''
                Whether this /etc file should be generated.  This
                option allows specific /etc files to be disabled.
              '';
            };

            target = lib.mkOption {
              type = lib.types.str;
              description = ''
                Name of symlink (relative to
                {file}`/etc`).  Defaults to the attribute
                name.
              '';
            };

            text = lib.mkOption {
              type = with lib.types; nullOr lines;
              default = null;
              description = "Text of the file.";
            };

            source = lib.mkOption {
              type = lib.types.path;
              description = "Path of the source file.";
            };

            mode = lib.mkOption {
              type = lib.types.str;
              default = "symlink";
              example = "0600";
              description = ''
                If set to something else than `symlink`,
                the file is copied instead of symlinked, with the given
                file mode.
              '';
            };

            uid = lib.mkOption {
              type = lib.types.int;
              default = 0;
              description = ''
                UID of created file. Only takes effect when the file is
                copied (that is, the mode is not 'symlink').
              '';
            };

            gid = lib.mkOption {
              type = lib.types.int;
              default = 0;
              description = ''
                GID of created file. Only takes effect when the file is
                copied (that is, the mode is not 'symlink').
              '';
            };

            user = lib.mkOption {
              type = lib.types.str;
              default = "+${toString config.uid}";
              description = ''
                User name of created file.
                Only takes effect when the file is copied (that is, the mode is not 'symlink').
                Changing this option takes precedence over `uid`.
              '';
            };

            group = lib.mkOption {
              type = lib.types.str;
              default = "+${toString config.gid}";
              description = ''
                Group name of created file.
                Only takes effect when the file is copied (that is, the mode is not 'symlink').
                Changing this option takes precedence over `gid`.
              '';
            };

          };

          config = {
            target = lib.mkDefault name;
            source = lib.mkIf (config.text != null) (
              let
                name' = "etc-" + lib.replaceStrings [ "/" ] [ "-" ] name;
              in
              lib.mkDerivedConfig options.text (pkgs.writeText name')
            );
          };
        }
      )
    );
    default = { };
    example = lib.literalExpression ''
      { example-configuration-file =
          { source = "/nix/store/.../etc/dir/file.conf.example";
            mode = "0440";
          };
        "default/useradd".text = "GROUP=100 ...";
      }
    '';
    description = ''
      Set of files that have to be linked in {file}`/etc`.
    '';
  };

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
