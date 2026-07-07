{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.nftables;

  tableSubmodule =
    { name, ... }:
    {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable this table.";
        };

        name = lib.mkOption {
          type = lib.types.str;
          description = "Table name.";
        };

        content = lib.mkOption {
          type = lib.types.lines;
          description = "The table content.";
        };

        family = lib.mkOption {
          description = "Table family.";
          type = lib.types.enum [
            "ip"
            "ip6"
            "inet"
            "arp"
            "bridge"
            "netdev"
          ];
        };
      };

      config = {
        name = lib.mkDefault name;
      };
    };

  enabledTables = lib.filterAttrs (_: table: table.enable) cfg.tables;

  deletions = ''
    ${
      if cfg.flushRuleset then
        "flush ruleset"
      else
        lib.concatStringsSep "\n" (
          lib.mapAttrsToList (_: table: ''
            table ${table.family} ${table.name}
            delete table ${table.family} ${table.name}
          '') enabledTables
        )
    }
    ${cfg.extraDeletions}
  '';

  deletionsFile = pkgs.writeText "nftables-deletions.nft" deletions;
in
{
  imports = [
    ./providers.firewall.nix
  ];

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

    checkRuleset = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Run `nft check` on the ruleset to spot syntax errors during build.
        Because this is executed in a sandbox, the check might fail if it requires
        access to any environmental factors or paths outside the Nix store.
        To circumvent this, the ruleset file can be edited using the preCheckRuleset
        option to work in the sandbox environment.
      '';
    };

    checkRulesetRedirects = lib.mkOption {
      type = lib.types.addCheck (lib.types.attrsOf lib.types.path) (
        attrs: lib.all lib.types.path.check (lib.attrNames attrs)
      );
      default = {
        "/etc/hosts" = config.environment.etc.hosts.source;
        "/etc/protocols" = config.environment.etc.protocols.source;
        "/etc/services" = config.environment.etc.services.source;
      };
      defaultText = lib.literalExpression ''
        {
          "/etc/hosts" = config.environment.etc.hosts.source;
          "/etc/protocols" = config.environment.etc.protocols.source;
          "/etc/services" = config.environment.etc.services.source;
        }
      '';
      description = ''
        Set of paths that should be intercepted and rewritten while checking the ruleset
        using `pkgs.buildPackages.libredirect`.
      '';
    };

    preCheckRuleset = lib.mkOption {
      type = lib.types.lines;
      default = "";
      example = lib.literalExpression ''
        # replace users/groups that don't exist in the test
        sed 's/skgid meadow/skgid root/g' -i ruleset.conf
      '';
      description = ''
        This script gets run before the ruleset is checked. It can be used to
        create additional files needed for the ruleset check to work, or modify
        the ruleset for cases the build environment cannot cover.
      '';
    };

    flushRuleset = lib.mkEnableOption "flushing the entire ruleset on each start";

    extraDeletions = lib.mkOption {
      type = lib.types.lines;
      default = "";
      example = ''
        # this makes deleting a non-existing table a no-op instead of an error
        table inet some-table;

        delete table inet some-table;
      '';
      description = ''
        Extra deletion commands to be run on every firewall start and
        after stopping the firewall.
      '';
    };

    ruleset = lib.mkOption {
      type = lib.types.lines;
      default = "";
      example = ''
        table inet filter {
          chain input {
            type filter hook input priority filter; policy drop;
            tcp dport 22 accept
          }
        }
      '';
      description = ''
        The ruleset to be used with nftables. Should be in a format that
        can be loaded using "/bin/nft -f". Definitions from multiple modules
        are concatenated, allowing rules to be contributed without
        overwriting each other. Note that if the tables should be cleaned
        first, either:
        - services.nftables.flushRuleset = true; needs to be set (flushes all tables)
        - services.nftables.extraDeletions needs to be set
        - or services.nftables.tables can be used, which will clean up the table automatically
      '';
    };

    rulesetFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        The ruleset file to be used with nftables. Should be in a format that
        can be loaded using "nft -f".
      '';
    };

    flattenRulesetFile = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Use `builtins.readFile` rather than `include` to handle {option}`rulesetFile`.
        It is useful when you want to apply {option}`preCheckRuleset` to
        {option}`rulesetFile`.

        ::: {.note}
        It is expected that {option}`rulesetFile` can be accessed from the build sandbox.
        :::
      '';
    };

    tables = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule tableSubmodule);
      default = { };
      example = lib.literalExpression ''
        {
          filter = {
            family = "inet";
            content = '''
              chain input {
                type filter hook input priority filter; policy drop;
                tcp dport 22 accept
              }
            ''';
          };
        }
      '';
      description = ''
        Tables to be added to the ruleset.
        Tables will be added together with delete statements to clean up the
        table before every update.
      '';
    };

    configFile = lib.mkOption {
      type = lib.types.path;
      default = pkgs.writeTextFile {
        name = "nftables.conf";
        text = ''
          ${deletions}
          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList (_: table: ''
              table ${table.family} ${table.name} {
                ${table.content}
              }
            '') enabledTables
          )}
          ${cfg.ruleset}
          ${
            if cfg.rulesetFile != null then
              if cfg.flattenRulesetFile then
                builtins.readFile cfg.rulesetFile
              else
                ''
                  include "${cfg.rulesetFile}"
                ''
            else
              ""
          }
        '';
        checkPhase = lib.optionalString cfg.checkRuleset ''
          cp $out ruleset.conf
          ${cfg.preCheckRuleset}
          export NIX_REDIRECTS=${
            lib.escapeShellArg (
              lib.concatStringsSep ":" (lib.mapAttrsToList (n: v: "${n}=${v}") cfg.checkRulesetRedirects)
            )
          }
          LD_PRELOAD="${pkgs.buildPackages.libredirect}/lib/libredirect.so ${pkgs.buildPackages.lklWithFirewall.lib}/lib/liblkl-hijack.so" \
            ${pkgs.buildPackages.nftables}/bin/nft --check --file ruleset.conf
        '';
      };
      defaultText = lib.literalMD "a configuration file generated from `tables`, `ruleset` and `rulesetFile`";
      description = ''
        The complete nftables configuration file. Setting this takes precedence
        over {option}`tables`, {option}`ruleset` and {option}`rulesetFile`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # boot.blacklistedKernelModules = [ "ip_tables" ];

    environment.systemPackages = [ cfg.package ];

    finit.tasks.nftables = {
      runlevels = "23";
      conditions = "service/syslogd/ready";
      command = "${lib.getExe cfg.package} -f ${cfg.configFile}";
      post = pkgs.writeShellScript "nftables.sh" ''
        ${lib.getExe cfg.package} -f ${deletionsFile}
      '';
      log = true;
      remain = true;
    };
  };
}
