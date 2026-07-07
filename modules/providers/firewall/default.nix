{
  config,
  lib,
  ...
}:
let
  cfg = config.providers.firewall;

  canonicalizePortList = ports: lib.unique (builtins.sort builtins.lessThan ports);
in
{
  options.providers.firewall = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable the firewall. This is a simple stateful firewall that
        blocks connection attempts to unauthorised TCP or UDP ports on this machine.
      '';
    };

    backend = lib.mkOption {
      type = lib.types.enum [ "none" ];
      default = "none";
      description = ''
        The selected module which should implement functionality for the
        {option}`providers.firewall` contract.
      '';
    };

    trustedInterfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "enp0s2" ];
      description = ''
        Traffic from these interfaces will be accepted unconditionally.
        The loopback interface is always trusted.
      '';
    };

    allowPing = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to respond to incoming ICMPv4 echo requests ("pings").
      '';
    };

    rejectPackets = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        If set, refused packets are rejected rather than dropped. This sends an
        ICMP "port unreachable" error back to the client (or a TCP RST for
        existing connections), allowing clients to fail fast rather than timeout.
        Rejecting packets makes port scanning somewhat easier.
      '';
    };

    allowedTCPPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ ];
      apply = canonicalizePortList;
      example = [
        22
        80
        443
      ];
      description = ''
        List of TCP ports on which incoming connections are accepted.
      '';
    };

    allowedTCPPortRanges = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.port);
      default = [ ];
      example = [
        {
          from = 8999;
          to = 9003;
        }
      ];
      description = ''
        A range of TCP ports on which incoming connections are accepted.
      '';
    };

    allowedUDPPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [ ];
      apply = canonicalizePortList;
      example = [ 53 ];
      description = ''
        List of open UDP ports.
      '';
    };

    allowedUDPPortRanges = lib.mkOption {
      type = lib.types.listOf (lib.types.attrsOf lib.types.port);
      default = [ ];
      example = [
        {
          from = 60000;
          to = 61000;
        }
      ];
      description = ''
        Range of open UDP ports.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.backend != "none";
        message = ''
          providers.firewall is enabled but no backend implements it. Enable an
          implementation module, e.g. services.nftables or services.iptables.
        '';
      }
    ];

    providers.firewall.trustedInterfaces = [ "lo" ];
  };
}
