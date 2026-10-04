{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.dash;
  dashCommand =
    if cfg.wrapper.enable then
      "${lib.getExe cfg.wrapper.package} ${cfg.wrapper.extraArgs} ${cfg.package}${cfg.package.shellPath}"
    else
      lib.getExe pkgs.dash;
  dashInteractive =
    pkgs.writeScriptBin "dashInteractive" ''
      #!${lib.getExe config.programs.sh.package}
      exec ${dashCommand} -il
    ''
    // {
      shellPath = "/bin/dashInteractive";
    };
in
{
  options.programs.dash = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [dash](${pkgs.dash.meta.homepage}), ${pkgs.dash.meta.description}.
      '';
    };

    package = lib.mkOption {
      type = lib.types.shellPackage;
      default = dashInteractive;
      description = ''
        The package to use for `dash`.
      '';
    };
    wrapper = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable wrapping for dashInteractive
        '';
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.rlwrap;
        defaultText = lib.literalExpression "pkgs.rlwrap";
        description = ''
          Package to use for wrapping dash
        '';
      };
      extraArgs = lib.mkOption {
        type = lib.types.str;
        default = " ";
        description = ''
          Extra arguments used for wrapping dash
        '';
        example = "--history-file ~/.dash_history --always-readline --no-children";
      };
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
        Shell script code called during interactive dash shell initialisation.
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

    environment.etc."profile.d/dash.sh".text = ''
      ENV=/etc/dashrc
    '';

    environment.etc.dashrc.text = ''
      # /etc/dashrc: system-wide configuration for interactive dash shells.

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
