{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.autofs;

  format = pkgs.formats.ini { };
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
      type = format.type;
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

    autoMaster = lib.mkOption {
      type = lib.types.str;
      example = lib.literalExpression ''
        let
          # Media Transfer Protocol (MTP) is used in some Android devices
          # https://wiki.archlinux.org/title/Autofs#MTP
          autoMisc = pkgs.writeText "auto.misc" '''
            android -fstype=fuse,allow_other,umask=000     :mtpfs
          ''';
        in '''
          /media/misc  file:''${autoMisc}  --timeout=60
        '''
      '';
      description = ''
        Master Map configuration. See {manpage}`auto.master(5)`
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.autofs.extraArgs = [ "--foreground" ] ++ lib.optionals cfg.debug [ "--debug" ];

    boot.kernelModules = [ "autofs" ];

    environment.etc."auto.master".text = cfg.autoMaster;
    environment.etc."autofs.conf".source = format.generate "autofs.conf" cfg.settings;

    finit.services.autofs = {
      description = "on-demand filesystem automounter";
      conditions = "service/syslogd/ready";
      command = "${lib.getExe cfg.package} " + lib.escapeShellArgs cfg.extraArgs;
      log = true;
    };
  };
}
