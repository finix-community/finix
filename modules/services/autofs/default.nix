{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.autofs;

  format = pkgs.formats.ini { };

  mountRuleOptions = {
    options = {
      mountPoint = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
      };

      source = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
      };

      rules = lib.mkOption {
        type = with lib.types; nullOr (listOf str);
        default = [
          "rw"
          "soft"
          "rsize=8192"
          "wsize=8192"
        ];
        description = ''
          List of options to apply to mount. Strings are stripped of spaces.
        '';
      };

      fsType = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        description = ''
          File system type. String is stripped of spaces.
        '';
      };

      group = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        description = ''
          Group to mount this file system as. String is stripped of spaces.
        '';
      };

      user = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        description = ''
          User to mount this file system as. String is stripped of spaces.
        '';
      };
    };
  };

  mountCollection = {
    options = {
      rootMountPoint = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
      };

      extraArgs = lib.mkOption {
        type = with lib.types; nullOr (listOf str);
        default = null;
      };

      mounts = lib.mkOption {
        type = with lib.types; attrsOf (submodule mountRuleOptions);
        default = { };
      };
    };
  };

in
{
  options.services.autofs = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [autofs](${pkgs.autofs5.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.autofs5;
      defaultText = lib.literalExpression "pkgs.autofs5";
      description = ''
        The package to use for `autofs`.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.
      '';
    };

    settings = lib.mkOption {
      inherit (format) type;
      default = { };
      description = ''
        `autofs` configuration. See {manpage}`autofs.conf(5)`
        for additional details.
      '';
    };

    extraArgs = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = ''
        Additional arguments to pass to `autofs`. See {manpage}`automount(8)`
        for additional details.
      '';
    };

    extraMasterConfig = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = ''
        Additional mount lines to add to `auto.master`. See {manpage}`auto.master(5)`
        for additional details.
      '';
    };

    mountCollections = lib.mkOption {
      type = with lib.types; attrsOf (submodule mountCollection);
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    services.autofs.extraArgs = [ "--foreground" ] ++ lib.optionals cfg.debug [ "--debug" ];

    boot.kernelModules = [ "autofs" ];

    environment.etc = lib.mkMerge [
      {
        "autofs.conf".source = format.generate "autofs.conf" cfg.settings;
        "auto.master".text = lib.mkMerge [
          (lib.strings.concatStringsSep "\n" (
            lib.attrsets.mapAttrsToList (
              n: v: v.rootMountPoint + " /etc/autofs/auto." + n + " " + (lib.concatStringsSep " " v.extraArgs)
            ) cfg.mountCollections
          ))

          (lib.strings.concatStringsSep "\n" cfg.extraMasterConfig)
        ];
      }

      (lib.attrsets.mapAttrs' (
        n: v1:
        lib.nameValuePair ("autofs/auto." + n) {
          text = lib.concatStringsSep "\n" (
            lib.attrsets.mapAttrsToList (
              n: v2:
              (if v2.mountPoint != null then v2.mountPoint else n)
              + " -"
              + (lib.strings.replaceString " " "" (
                lib.concatStringsSep "," (
                  v2.rules
                  ++ (lib.lists.optional (v2.fsType != null) "fstype=${lib.strings.replaceString " " "" v2.fsType}")
                  ++ (lib.lists.optional (v2.group != null) "group=${lib.strings.replaceString " " "" v2.group}")
                  ++ (lib.lists.optional (v2.user != null) "user=${lib.strings.replaceString " " "" v2.user}")
                )
              ))
              + " "
              + v2.source
            ) v1.mounts
          );
        }
      ) cfg.mountCollections)
    ];

    finit.services.autofs = {
      description = "on-demand filesystem automounter";
      conditions = "service/syslogd/ready";
      command = "${lib.getExe cfg.package} " + lib.escapeShellArgs cfg.extraArgs;
      log = true;
    };
  };
}
