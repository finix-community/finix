{ config, pkgs, lib, ... }:
let
  cfg = config.services.system76-scheduler;
in
{
  options.services.system76-scheduler = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [system76-scheduler](${pkgs.system76-scheduler.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.system76-scheduler;
      defaultText = lib.literalExpression "pkgs.system76-scheduler";
      description = ''
        The package to use for `system76-scheduler`.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.
      '';
    };

    configFile = lib.mkOption {
      type = lib.types.path;
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc."system76-scheduler/config.kdl".source = cfg.configFile;
    environment.systemPackages = [ cfg.package ];
    services.dbus.packages = [ cfg.package ];

    finit.services.system76-scheduler = {
      description = "system76 scheduler";
      command = "${lib.getExe cfg.package} daemon";
      reload = "${lib.getExe cfg.package} daemon reload";
      conditions = [ "service/syslogd/ready" "service/dbus/ready" ];
      log = true;

      # TODO: now we're hijacking `env` and no one else can use it...
      env = pkgs.writeText "system76-scheduler.env" (''
        NO_COLOR=1
        PATH="${lib.makeBinPath [ pkgs.kmod pkgs.gnutar pkgs.xz ]}:$PATH"
      '' + lib.optionalString cfg.debug ''
        RUST_LOG=system76_scheduler=debug
      '');
    };
  };
}
