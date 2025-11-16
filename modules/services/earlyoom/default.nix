{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.earlyoom;
in
{
  options.services.earlyoom = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [earlyoom](${pkgs.earlyoom.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.earlyoom;
      defaultText = lib.literalExpression "pkgs.earlyoom";
      description = ''
        The package to use for `earlyoom`.
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
      example = [
        "-r"
        "3600"
      ];
      description = ''
        Additional arguments to pass to `earlyoom`. See {manpage}`earlyoom(1)`
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.earlyoom.extraArgs = [ "-p" ] ++ lib.optionals cfg.debug [ "--debug" ];

    finit.services.earlyoom = {
      description = "early oom daemon";
      command = "${cfg.package}/bin/earlyoom --syslog " + lib.escapeShellArgs cfg.extraArgs;
      conditions = "service/syslogd/ready";
      nohup = true;

      cgroup.settings = {
        "memory.max" = "50M";
        "pids.max" = 10;
      };

      # TODO: now we're hijacking `env` and no one else can use it...
      environment = lib.optionalAttrs (lib.elem "-n" cfg.extraArgs) {
        PATH = "${lib.makeBinPath [ pkgs.dbus ]}:$PATH";
      };
    };
  };
}
