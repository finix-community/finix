{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.thermald;
in
{
  options.services.thermald = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [thermald](${pkgs.thermald.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.thermald;
      defaultText = lib.literalExpression "pkgs.thermald";
      description = ''
        The package to use for `thermald`.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.
      '';
    };

    extraArgs = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = ''
        Additional arguments to pass to `thermald`. See {manpage}`thermald(8)`
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.thermald.extraArgs = [
      "--adaptive"
      "--dbus-enable"
      "--no-daemon"
    ]
    ++ lib.optionals cfg.debug [ "--loglevel=debug" ];

    services.dbus.packages = [ cfg.package ];

    finit.services.thermald = {
      description = "thermal daemon service";
      conditions = "service/syslogd/ready";
      command = "${lib.getExe cfg.package} " + lib.escapeShellArgs cfg.extraArgs;
      log = true;
      nohup = true;
    };
  };
}
