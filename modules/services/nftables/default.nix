{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.nftables;

  # https://github.com/orgs/finit-project/discussions/456#discussioncomment-15089136
  nft-helper = pkgs.stdenv.mkDerivation {
    name = "nft-helper";
    src = pkgs.fetchFromGitHub {
      owner = "kernelkit";
      repo = "curiOS";
      rev = "80ee64156672694992c866292c5d30ff5683d2db";
      hash = "sha256-dS8PELYZifu+soMOePukUT93IFG/wPIyHABsabxcaxc=";
    };

    sourceRoot = "source/src/nft-helper";
    installPhase = "install -Dm755 nft-helper $out/bin/nft-helper";
    meta.mainProgram = "nft-helper";
  };
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

    finit.services.nftables = {
      conditions = "service/syslogd/ready";
      command = "${lib.getExe nft-helper} ${cfg.configFile}";
      log = true;
      nohup = true;
      path = [ cfg.package ];
    };
  };
}
