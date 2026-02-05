{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.nftables;
in
{
  options.services.nftables = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [nftables](${pkgs.nftables.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nftables;
      defaultText = lib.literalExpression "pkgs.nftables";
      description = ''
        The package to use for `nftables`.
      '';
    };

    configFile = lib.mkOption {
      type = lib.types.path;
      default = pkgs.writeText "nftables.conf" ''
        flush ruleset

        table inet filter {
        	chain input {
        		type filter hook input priority filter;
        	}
        	chain forward {
        		type filter hook forward priority filter;
        	}
        	chain output {
        		type filter hook output priority filter;
        	}
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # boot.blacklistedKernelModules = [ "ip_tables" ];

    environment.systemPackages = [ cfg.package ];

    finit.tasks.nftables = {
      conditions = "service/syslogd/ready";
      command = "${lib.getExe cfg.package} -f ${cfg.configFile}";
      post = pkgs.writeShellScript "nftables.sh" ''
        ${lib.getExe cfg.package} flush ruleset
      '';
      log = true;
      remain = true;
    };
  };
}
