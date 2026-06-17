{
  modules,
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.sshguard;

  format = pkgs.formats.keyValue { };
in
{
  imports = [ modules.nftables ];

  options.services.sshguard = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [sshguard](${pkgs.sshguard.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.sshguard;
      defaultText = lib.literalExpression "pkgs.sshguard";
      description = ''
        The package to use for `sshguard`.
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
      type = lib.types.submodule {
        freeformType = format.type;

        options = {
          BACKEND = lib.mkOption {
            type = lib.types.enum [
              "nft-sets"

              # TODO: potential future work
              # "firewalld"
              # "hosts"
              # "ipfilter"
              # "ipfw"
              # "ipset"
              # "iptables"
              # "null"
              # "pf"
            ];
            description = ''
              Backend executable.
            '';
          };

          FILES = lib.mkOption {
            type = with lib.types; listOf path;
            apply = lib.concatStringsSep " ";
            description = ''
              Log files to monitor.
            '';
            example = [ "/var/log/auth.log" ];
          };
        };
      };
      default = { };
      description = ''
        `sshguard` configuration. See [upstream documentation](https://github.com/SSHGuard/sshguard/tree/master/examples)
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.nftables.enable = lib.mkIf (cfg.settings.BACKEND == "nft-sets") true;

    environment.etc."sshguard.conf".source = format.generate "sshguard.conf" (
      lib.filterAttrs (_: v: v != null) (
        cfg.settings
        // {
          BACKEND = "${cfg.package}/libexec/sshg-fw-${cfg.settings.BACKEND}";
        }
      )
    );

    finit.services.sshguard = {
      command = lib.getExe cfg.package;
      conditions = [
        "service/syslogd/ready"
        "net/route/default"
      ]
      ++ lib.optionals (cfg.settings.BACKEND == "nft-sets") [
        "task/nftables/success"
      ];
      log = true;
      path = [
        config.programs.coreutils.package
      ]
      ++ lib.optionals (cfg.settings.BACKEND == "nft-sets") [ config.services.nftables.package ];

      environment = lib.optionalAttrs cfg.debug {
        SSHGUARD_DEBUG = 1;
      };
    };
  };
}
