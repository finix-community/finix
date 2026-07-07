{
  config,
  lib,
  ...
}:
let
  cfg = config.providers.firewall;

  nft = "${cfg.package}/bin/nft";

  portsToNftSet =
    ports: portRanges:
    lib.concatStringsSep ", " (
      map toString ports ++ map ({ from, to }: "${toString from}-${toString to}") portRanges
    );

  ifaceSet = lib.concatStringsSep ", " (map (x: ''"${x}"'') cfg.trustedInterfaces);

  tcpSet = portsToNftSet cfg.allowedTCPPorts cfg.allowedTCPPortRanges;
  udpSet = portsToNftSet cfg.allowedUDPPorts cfg.allowedUDPPortRanges;

  nftablesConf = ''
    table inet finix-fw {
      chain input {
        type filter hook input priority filter; policy drop;

        ${lib.optionalString (
          ifaceSet != ""
        ) ''iifname { ${ifaceSet} } accept comment "trusted interfaces"''}

        ct state vmap {
          invalid : drop,
          established : accept,
          related : accept,
          new : jump input-allow,
          untracked : jump input-allow,
        }

        ${lib.optionalString cfg.rejectPackets ''
          meta l4proto tcp reject with tcp reset
          reject
        ''}
      }

      chain input-allow {
        ${lib.optionalString (tcpSet != "") "tcp dport { ${tcpSet} } accept"}
        ${lib.optionalString (udpSet != "") "udp dport { ${udpSet} } accept"}

        ${lib.optionalString cfg.allowPing ''
          icmp type echo-request accept comment "allow ping"
          icmpv6 type echo-request accept comment "allow ping6"
        ''}
      }
    }
  '';
in
{
  config = lib.mkIf (cfg.enable && cfg.backend == "nftables") {
    environment.etc."nftables.conf".text = nftablesConf;

    finit.tasks.firewall = {
      description = "firewall rules (nftables)";
      command = "${nft} -f /etc/nftables.conf";
      runlevels = "S";
    };
  };
}
