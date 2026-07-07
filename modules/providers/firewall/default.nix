{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.providers.firewall;

  canonicalizePortList = ports: lib.unique (builtins.sort builtins.lessThan ports);

  commonOptions = {
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
in
{
  imports = [
    ./iptables.nix
    ./nftables.nix
    ./test.nix
  ];

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
      type = lib.types.enum [
        "iptables"
        "nftables"
      ];
      default = "nftables";
      description = ''
        Underlying implementation for the firewall service.

        - `iptables`: IPv4 packet filtering via iptables.
        - `nftables`: Unified IPv4/IPv6 packet filtering via nftables.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = if cfg.backend == "nftables" then pkgs.nftables else pkgs.iptables;
      defaultText = lib.literalExpression "pkgs.nftables or pkgs.iptables depending on backend";
      description = ''
        The package to use for running the firewall service.
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

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "[ pkgs.ipset ]";
      description = ''
        Additional packages to be included in the system environment alongside
        the firewall package.
      '';
    };
  }
  // commonOptions;

  config = lib.mkIf cfg.enable {
    providers.firewall.trustedInterfaces = [ "lo" ];

    environment.systemPackages = [ cfg.package ] ++ cfg.extraPackages;
  };
}
