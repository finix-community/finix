{ config, pkgs, lib, ... }:
let
  pamOpts = { name, ... }: {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = name;
      };

      text = lib.mkOption {
        type = lib.types.lines;
      };
    };
  };

  cfg = config.security.pam;
in
{
  options.security.pam = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    services = lib.mkOption {
      type = with lib.types; attrsOf (submodule pamOpts);
      default = { };
    };

    environment = lib.mkOption {
      description = "Set of rules for pam_env.";
      type = lib.types.submodule {
        options =
          let
            opt = lib.mkOption {
              type = with lib.types; nullOr str;
              default = null;
            };
          in {
            default = opt;
            override = opt;
          };
      } |> lib.types.attrsOf;
    };
  };

  config = {
    environment.etc =
      let
        etcTree = lib.mapAttrs' (k: v: lib.nameValuePair "pam.d/${k}" {
          inherit (v) text;
        }) (lib.filterAttrs (_: v: v.enable) config.security.pam.services);

        debug = lib.mkIf config.security.pam.debug {
          "pam_debug".text = "";
        };

        pam_env."security/pam_env.conf".text =
          let
            toField = key: val: lib.optionalString (val != null) " ${key}=${lib.escapeShellArg val}";
          in lib.concatMapAttrsStringSep "\n" (
            var: { default, override }: "${var}${toField "DEFAULT" default}${toField "OVERRIDE" override}"
          ) cfg.environment;
      in
        lib.mkMerge [ debug pam_env etcTree ];

    security.pam.environment = lib.mapAttrs (_: v: { default = lib.mkDefault v; }) {
      EDITOR = "micro";
      NIX_REMOTE = "daemon";
      NIX_XDG_DESKTOP_PORTAL_DIR = "/run/current-system/sw/share/xdg-desktop-portal/portals";
      PATH = "${config.security.wrapperDir}:/run/current-system/sw/bin";
      XCURSOR_PATH = "/run/current-system/sw/share/icons:/run/current-system/sw/share/pixmaps";
      XDG_CONFIG_DIRS = "/etc/xdg:/run/current-system/sw/etc/xdg";
      XDG_DATA_DIRS = "/run/current-system/sw/share";
    };

    security.pam.services.other = {
      text = ''
        auth     required pam_warn.so
        auth     required pam_deny.so
        account  required pam_warn.so
        account  required pam_deny.so
        password required pam_warn.so
        password required pam_deny.so
        session  required pam_warn.so
        session  required pam_deny.so
      '';
    };

    security.wrappers = {
      unix_chkpwd = {
        setuid = true;
        owner = "root";
        group = "root";
        source = "${pkgs.pam}/bin/unix_chkpwd";
      };
    };
  };
}
