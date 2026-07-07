{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.iptables;

  kernel = config.boot.kernelPackages.kernel;

  kernelHasRPFilter =
    ((kernel.config.isEnabled or (x: false)) "IP_NF_MATCH_RPFILTER")
    || (kernel.features.netfilterRPFilter or false);

  helpers = ''
    # Helper command to manipulate both the IPv4 and IPv6 tables.
    ip46tables() {
      ${cfg.package}/bin/iptables -w "$@"
      ${cfg.package}/bin/ip6tables -w "$@"
    }
  '';

  acceptAllRules = ''
    *filter
    :INPUT ACCEPT [0:0]
    :FORWARD ACCEPT [0:0]
    :OUTPUT ACCEPT [0:0]
    COMMIT
  '';

  rulesV4 = pkgs.writeText "iptables-rules.v4" cfg.rulesetV4;
  rulesV6 = pkgs.writeText "iptables-rules.v6" cfg.rulesetV6;

  flushRules = pkgs.writeText "iptables-flush" acceptAllRules;

  startScript = pkgs.writeShellScript "iptables-start.sh" ''
    ${helpers}

    ${cfg.package}/bin/iptables-restore ${rulesV4}
    ${cfg.package}/bin/ip6tables-restore ${rulesV6}

    # Clean up rpfilter rules
    ip46tables -t mangle -D PREROUTING -j finix-fw-rpfilter 2> /dev/null || true
    ip46tables -t mangle -F finix-fw-rpfilter 2> /dev/null || true
    ip46tables -t mangle -X finix-fw-rpfilter 2> /dev/null || true

    ${lib.optionalString (kernelHasRPFilter && (cfg.checkReversePath != false)) ''
      # Perform a reverse-path test to refuse spoofers
      # For now, we just drop, as the mangle table doesn't have a log-refuse yet
      ip46tables -t mangle -N finix-fw-rpfilter 2> /dev/null || true
      ip46tables -t mangle -A finix-fw-rpfilter -m rpfilter --validmark ${
        lib.optionalString (cfg.checkReversePath == "loose") "--loose"
      } -j RETURN

      # Allows this host to act as a DHCP4 client without first having to use APIPA
      ${cfg.package}/bin/iptables -w -t mangle -A finix-fw-rpfilter -p udp --sport 67 --dport 68 -j RETURN

      # Allows this host to act as a DHCPv4 server
      ${cfg.package}/bin/iptables -w -t mangle -A finix-fw-rpfilter -s 0.0.0.0 -d 255.255.255.255 -p udp --sport 68 --dport 67 -j RETURN

      ${lib.optionalString cfg.logReversePathDrops ''
        ip46tables -t mangle -A finix-fw-rpfilter -j LOG --log-level info --log-prefix "rpfilter drop: "
      ''}
      ip46tables -t mangle -A finix-fw-rpfilter -j DROP

      ip46tables -t mangle -A PREROUTING -j finix-fw-rpfilter
    ''}

    ${cfg.extraCommands}
  '';

  stopScript = pkgs.writeShellScript "iptables-stop.sh" ''
    ${helpers}

    ${cfg.package}/bin/iptables-restore ${flushRules}
    ${cfg.package}/bin/ip6tables-restore ${flushRules}

    ip46tables -t mangle -D PREROUTING -j finix-fw-rpfilter 2> /dev/null || true
    ip46tables -t mangle -F finix-fw-rpfilter 2> /dev/null || true
    ip46tables -t mangle -X finix-fw-rpfilter 2> /dev/null || true

    ${cfg.extraStopCommands}
  '';
in
{
  imports = [
    ./providers.firewall.nix
  ];

  options.services.iptables = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [iptables](${pkgs.iptables.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.iptables;
      defaultText = lib.literalExpression "pkgs.iptables";
      description = ''
        The package to use for `iptables`.
      '';
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "[ pkgs.ipset ]";
      description = ''
        Additional packages to be included in the system environment alongside
        the iptables package.
      '';
    };

    rulesetV4 = lib.mkOption {
      type = lib.types.lines;
      default = acceptAllRules;
      description = ''
        The IPv4 ruleset, in {manpage}`iptables-restore(8)` format.
      '';
    };

    rulesetV6 = lib.mkOption {
      type = lib.types.lines;
      default = acceptAllRules;
      description = ''
        The IPv6 ruleset, in {manpage}`ip6tables-restore(8)` format.
      '';
    };

    checkReversePath = lib.mkOption {
      type = lib.types.either lib.types.bool (
        lib.types.enum [
          "strict"
          "loose"
        ]
      );
      default = false;
      example = "loose";
      description = ''
        Performs a reverse path filter test on a packet. If a reply
        to the packet would not be sent via the same interface that
        the packet arrived on, it is refused.

        If using asymmetric routing or other complicated routing, set
        this option to loose mode or disable it and setup your own
        counter-measures.

        This option can be either true (or "strict"), "loose" (only
        drop the packet if the source address is not reachable via any
        interface) or false.
      '';
    };

    logReversePathDrops = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Logs dropped packets failing the reverse path filter test if
        the option {option}`checkReversePath` is enabled.
      '';
    };

    extraCommands = lib.mkOption {
      type = lib.types.lines;
      default = "";
      example = "iptables -A INPUT -p icmp -j ACCEPT";
      description = ''
        Additional shell commands executed as part of the iptables
        initialisation script, after the rulesets have been loaded.
        An `ip46tables` helper is available to run a command against
        both the IPv4 and IPv6 tables.
      '';
    };

    extraStopCommands = lib.mkOption {
      type = lib.types.lines;
      default = "";
      example = "iptables -P INPUT ACCEPT";
      description = ''
        Additional shell commands executed as part of the iptables
        shutdown script, after the rulesets have been reset.
        An `ip46tables` helper is available to run a command against
        both the IPv4 and IPv6 tables.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      # This is approximately "checkReversePath -> kernelHasRPFilter",
      # but the checkReversePath option can include non-boolean
      # values.
      {
        assertion = cfg.checkReversePath == false || kernelHasRPFilter;
        message = "This kernel does not support rpfilter";
      }
    ];

    environment.systemPackages = [ cfg.package ] ++ cfg.extraPackages;

    finit.tasks.iptables = {
      runlevels = "23";
      conditions = "service/syslogd/ready";
      command = startScript;
      post = stopScript;
      log = true;
      remain = true;
    };
  };
}
