{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.xinit;

  sessionNames = lib.sort (a: b: a < b) (lib.attrNames cfg.sessions);

  mkSession =
    name:
    lib.concatStringsSep "\n" [
      "${name})"
      (lib.concatMapStringsSep "\n" (cmd: "  ${cmd}") cfg.sessions.${name})
      "  ;;"
    ];

  xinitrc = pkgs.writeText "xinitrc" (
    lib.concatStringsSep "\n" [
      "#!/bin/sh"
      ""
      "# merge X resources if present"
      "[ -f ~/.Xresources ] && xrdb -merge ~/.Xresources"
      ""
      "session=\"\${1:-}\""
      ""
      "case \"$session\" in"
      (lib.concatMapStringsSep "\n" mkSession sessionNames)
      "*)"
      "  echo \"unknown session: $session\""
      "  echo \"available sessions: ${lib.concatStringsSep " " sessionNames}\""
      "  exit 1"
      "  ;;"
      "esac"
    ]
  );
in
{
  options.programs.xinit = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [xinit](${pkgs.xinit.meta.homepage}).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default =
        (pkgs.xinit.override {
          xorg-server = config.programs.xorg.package or pkgs.xorg-server;
        }).overrideAttrs
          (
            o:
            lib.optionalAttrs config.security.wrappers.X.enable or false {
              # TODO: replace once https://github.com/NixOS/nixpkgs/pull/534421 is merged
              configureFlags = o.configureFlags or [ ] ++ [
                "--with-xserver=${config.security.wrapperDir}/X"
              ];
            }
          );
      defaultText = lib.literalExpression "pkgs.xinit";
      description = ''
        The package to use for `xinit`.
      '';
    };

    sessions = lib.mkOption {
      type = lib.types.attrsOf (lib.types.listOf lib.types.str);
      default = { };
      example = lib.literalExpression ''
        {
          "vxwm" = [ "pipewire &" "wireplumber &" "exec vxwm" ];
          "oxwm" = [ "sxhkd &" "exec openbox-session" ];
        }
      '';

      description = ''
        Sessions generated into {file}`/etc/X11/xinit/xinitrc`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.sessions != { };
        message = "programs.xinit.sessions must define at least one session when programs.xinit.enable = true.";
      }
      {
        assertion = lib.all (n: builtins.match "[A-Za-z0-9_-]+" n != null) sessionNames;
        message = "programs.xinit.sessions: session names may only contain [A-Za-z0-9_-]";
      }
    ];

    environment.etc."X11/xinit/xinitrc".source = xinitrc;
    environment.systemPackages = [ cfg.package ];
  };
}
