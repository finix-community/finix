{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.bash;

  bashAliases = builtins.concatStringsSep "\n" (
    lib.mapAttrsToList (k: v: "alias -- ${k}=${lib.escapeShellArg v}") (
      lib.filterAttrs (k: v: v != null) cfg.shellAliases
    )
  );
in
{
  options.programs.bash = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [bash](${pkgs.bash.meta.homepage}) as a system shell.
      '';
    };

    package = lib.mkOption {
      type = lib.types.shellPackage;
      default = pkgs.bashInteractive;
      defaultText = lib.literalExpression "pkgs.bashInteractive";
      description = ''
        The package to use for `bash`.
      '';
    };

    shellAliases = lib.mkOption {
      default = { };
      description = ''
        Set of aliases for bash shell.
      '';
      type = with lib.types; attrsOf (nullOr (either str path));
    };

    shellInit = lib.mkOption {
      default = "";
      description = ''
        Shell script code called during bash shell initialisation.
      '';
      type = lib.types.lines;
    };

    loginShellInit = lib.mkOption {
      default = "";
      description = ''
        Shell script code called during login bash shell initialisation.
      '';
      type = lib.types.lines;
    };

    interactiveShellInit = lib.mkOption {
      default = "";
      description = ''
        Shell script code called during interactive bash shell initialisation.
      '';
      type = lib.types.lines;
    };

    promptInit = lib.mkOption {
      default = ''
        # Provide a nice prompt if the terminal supports it.
        if [ "$TERM" != "dumb" ] || [ -n "$INSIDE_EMACS" ]; then
          PROMPT_COLOR="1;31m"
          ((UID)) && PROMPT_COLOR="1;32m"
          if [ -n "$INSIDE_EMACS" ]; then
            # Emacs term mode doesn't support xterm title escape sequence (\e]0;)
            PS1="\n\[\033[$PROMPT_COLOR\][\u@\h:\w]\\$\[\033[0m\] "
          else
            PS1="\n\[\033[$PROMPT_COLOR\][\[\e]0;\u@\h: \w\a\]\u@\h:\w]\\$\[\033[0m\] "
          fi
          if test "$TERM" = "xterm"; then
            PS1="\[\033]2;\h:\u:\w\007\]$PS1"
          fi
        fi
      '';
      description = ''
        Shell script code used to initialise the bash prompt.
      '';
      type = lib.types.lines;
    };

    promptPluginInit = lib.mkOption {
      default = "";
      description = ''
        Shell script code used to initialise bash prompt plugins.
      '';
      type = lib.types.lines;
      internal = true;
    };

    logout = lib.mkOption {
      default = ''
        printf '\e]0;\a'
      '';
      description = ''
        Shell script code called during login bash shell logout.
      '';
      type = lib.types.lines;
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra shell code appended to {file}`/etc/bashrc`.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    environment.shells = [
      "/run/current-system/sw${cfg.package.shellPath}"
      "${cfg.package}${cfg.package.shellPath}"
    ];

    environment.etc."profile.d/bash.sh".text = ''
      if [ -r /etc/profile.d/session-vars.sh ]; then
        . /etc/profile.d/session-vars.sh
      fi

      ${cfg.shellInit}
      ${cfg.loginShellInit}

      if [ -n "''${BASH_VERSION:-}" ] && [ -r /etc/bashrc ]; then
        . /etc/bashrc
      fi
    '';

    # NOTE: bash in nixpkgs is compiled with `SYS_BASHRC="/etc/bashrc"` which means:
    # - interactive non-login shells source this automatically
    # - login shells get it via the profile.d drop-in above
    environment.etc.bashrc.text = ''
      # /etc/bashrc: system-wide configuration for interactive bash shells.

      # We are not always an interactive shell.
      if [ -n "$PS1" ]; then
        # Check the window size after every command.
        shopt -s checkwinsize

        # Disable hashing (i.e. caching) of command lookups.
        set +h

        eval "$(${pkgs.coreutils}/bin/dircolors -b)"

        alias ls='ls --color=auto'

        ${cfg.promptInit}
        ${cfg.promptPluginInit}

        ${bashAliases}

        ${cfg.interactiveShellInit}
      fi

      ${cfg.extraConfig}
    '';

    environment.etc.bash_logout.text = ''
      # /etc/bash_logout: DO NOT EDIT -- this file has been generated automatically.

      ${cfg.logout}

      # Read system-wide modifications.
      if test -f /etc/bash_logout.local; then
          . /etc/bash_logout.local
      fi
    '';
  };
}
