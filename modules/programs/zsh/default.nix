{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.zsh;

  zshAliases = builtins.concatStringsSep "\n" (
    lib.mapAttrsToList (k: v: "alias -- ${k}=${lib.escapeShellArg v}") (
      lib.filterAttrs (k: v: v != null) cfg.shellAliases
    )
  );
in
{
  options.programs.zsh = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [zsh](${pkgs.zsh.meta.homepage}) as a system shell.
      '';
    };

    package = lib.mkOption {
      type = lib.types.shellPackage;
      default = pkgs.zsh;
      defaultText = lib.literalExpression "pkgs.zsh";
      description = ''
        The package to use for `zsh`.
      '';
    };

    shellAliases = lib.mkOption {
      default = { };
      description = ''
        Set of aliases for zsh shell.
      '';
      type = with lib.types; attrsOf (nullOr (either str path));
    };

    shellInit = lib.mkOption {
      default = "";
      description = ''
        Shell script code called during zsh shell initialisation.
      '';
      type = lib.types.lines;
    };

    loginShellInit = lib.mkOption {
      default = "";
      description = ''
        Shell script code called during login zsh shell initialisation.
      '';
      type = lib.types.lines;
    };

    interactiveShellInit = lib.mkOption {
      default = "";
      description = ''
        Shell script code called during interactive zsh shell initialisation.
      '';
      type = lib.types.lines;
    };

    promptInit = lib.mkOption {
      default = ''
        # Provide a nice prompt if the terminal supports it.
        if [ "$TERM" != "dumb" ] || [ -n "$INSIDE_EMACS" ]; then
          if (( UID )); then
            PS1='%F{green}%n@%m:%~%F{-}%#%f '
          else
            PS1='%F{red}%n@%m:%~%F{-}%#%f '
          fi
        fi
      '';
      description = ''
        Shell script code used to initialise the zsh prompt.
      '';
      type = lib.types.lines;
    };

    promptPluginInit = lib.mkOption {
      default = "";
      description = ''
        Shell script code used to initialise zsh prompt plugins.
      '';
      type = lib.types.lines;
      internal = true;
    };

    logout = lib.mkOption {
      default = ''
        printf '\e]0;\a'
      '';
      description = ''
        Shell script code called during login zsh shell logout.
      '';
      type = lib.types.lines;
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra shell code appended to {file}`/etc/zshrc`.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    environment.shells = [
      "/run/current-system/sw${cfg.package.shellPath}"
      "${cfg.package}${cfg.package.shellPath}"
    ];

    environment.etc.zshenv.text = ''
      # /etc/zshenv: system-wide, read by every zsh (even non-interactive).

      if [ -n "''${__FINIX_ZSHENV_SOURCED:-}" ]; then return; fi
      __FINIX_ZSHENV_SOURCED=1

      # zsh does not read /etc/profile, so pull in the POSIX drop-ins here.
      if [ -r /etc/profile ]; then
        . /etc/profile
      fi

      ${cfg.shellInit}

      if test -f /etc/zshenv.local; then
        . /etc/zshenv.local
      fi
    '';

    environment.etc.zprofile.text = ''
      # /etc/zprofile: read by login shells only.

      ${cfg.loginShellInit}

      if test -f /etc/zprofile.local; then
        . /etc/zprofile.local
      fi
    '';

    # NOTE: zsh in nixpkgs is compiled with `SYS_ZSHRC="/etc/zshrc"` which means:
    # - interactive non-login shells source this automatically
    # - interactive login shells source it as well, after /etc/zprofile
    environment.etc.zshrc.text = ''
      # /etc/zshrc: system-wide configuration for interactive zsh shells.

      # We are not always an interactive shell.
      if [[ -o interactive ]]; then
        eval "$(${pkgs.coreutils}/bin/dircolors -b)"

        alias ls='ls --color=auto'

        ${cfg.promptInit}
        ${cfg.promptPluginInit}

        ${zshAliases}

        ${cfg.interactiveShellInit}
      fi

      ${cfg.extraConfig}
    '';

    environment.etc.zsh_logout.text = ''
      # /etc/zsh_logout: DO NOT EDIT -- this file has been generated automatically.

      ${cfg.logout}

      # Read system-wide modifications.
      if test -f /etc/zsh_logout.local; then
          . /etc/zsh_logout.local
      fi
    '';
  };
}
