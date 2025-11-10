{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.zerotierone;
in
{
  options.services.zerotierone = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [zerotierone](${pkgs.zerotierone.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.zerotierone;
      defaultText = lib.literalExpression "pkgs.zerotierone";
      description = ''
        The package to use for `zerotierone`.
      '';
    };

    stateDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/zerotier-one";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelModules = [
      "tun"
    ];

    environment.systemPackages = [
      cfg.package
    ];

    finit.services.zerotierone = {
      description = "zerotier one";
      conditions = [
        "service/syslogd/ready"
        "net/route/default"
      ];
      command = "${cfg.package}/bin/zerotier-one ${cfg.stateDir}";
    };

    services.tmpfiles.zerotierone = lib.mkIf (cfg.stateDir == "/var/lib/zerotier-one") {
      rules = [
        "d ${cfg.stateDir}"

        # TODO: ${cfg.stateDir}/networks.d/<JOIN> -> managed by linker
      ];
    };
  };
}
