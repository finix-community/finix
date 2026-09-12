{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.ash;
  ashInteractive =
    pkgs.writeScriptBin "ashInteractive" ''
      #!${lib.getExe config.programs.sh.package}
      exec ${lib.getExe' pkgs.busybox "ash"} -il
    ''
    // {
      shellPath = "/bin/ashInteractive";
    };
in
{
  options.programs.ash = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [busybox](${pkgs.busybox.meta.homepage}'s ash.
      '';
    };

    package = lib.mkOption {
      type = lib.types.shellPackage;
      default = ashInteractive;
      description = ''
        The package to use for `ash`.
      '';
    };
    interactiveShellInit = lib.mkOption {
      default = ''
        # Provide a nice prompt if the terminal supports it.
        prompt() {
            color='1;31m'

            if [ "$(id -u)" -ne 0 ]; then
                color='1;32m'
            fi

            user=$(id -un)
            host=$(hostname)
            dir=$(pwd)

            case $dir in
                "$HOME")
                    dir='~'
                    ;;
                "$HOME"/*)
                    dir="~''${dir#"$HOME"}"
                    ;;
            esac

            if [ -n "''${INSIDE_EMACS-}" ]; then
                printf '\n\033[%s[%s@%s:%s]%s\033[0m ' \
                    "$color" "$user" "$host" "$dir" '$'
            else
                printf '\033]0;%s@%s: %s\007' \
                    "$user" "$host" "$dir"

                printf '\n\033[%s[%s@%s:%s]%s\033[0m ' \
                    "$color" "$user" "$host" "$dir" '$'
            fi
        }

        if [ "''${TERM-}" != "dumb" ] || [ -n "''${INSIDE_EMACS-}" ]; then
            PS1='$(prompt)'
        fi
      '';
      description = ''
        Shell script code called during interactive ash shell initialisation.
      '';
      type = lib.types.lines;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    environment.shells = [
      "/run/current-system/sw${cfg.package.shellPath}"
      "${cfg.package}${cfg.package.shellPath}"
    ];

    environment.etc."profile.d/ash.sh".text = ''
      ENV=/etc/ashrc
    '';

    environment.etc.ashrc.text = ''
      # /etc/ashrc: system-wide configuration for interactive ash shells.

      # We are not always an interactive shell.
      case $- in
        *i*)
          if [ -t 0 ]; then
            ${cfg.interactiveShellInit}
            alias ls='ls --color=auto'
          fi
          ;;
      esac
    '';
  };
}
