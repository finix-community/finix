{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.bash;
in
{
  imports = [ ./test.nix ];

  options.programs.bash = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [bash](${pkgs.bash.meta.homepage}).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.bashInteractive;
      defaultText = lib.literalExpression "pkgs.bashInteractive";
      description = ''
        The package to use for `bash`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    environment.shells = [
      "/run/current-system/sw/bin/bash"
      (lib.getExe cfg.package)
    ];

    environment.etc."profile.d/bash.sh".text = ''
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

        eval "$(${pkgs.coreutils}/bin/dircolors -b)"

        alias ls='ls --color=auto'
      fi
    '';
  };
}
