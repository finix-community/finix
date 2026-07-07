{
  config,
  lib,
  ...
}:
let
  cfg = config.providers.firewall;

  portsToNftSet =
    ports: portRanges:
    lib.concatStringsSep ", " (
      map toString ports ++ map ({ from, to }: "${toString from}-${toString to}") portRanges
    );

  ifaceSet = lib.concatStringsSep ", " (map (x: ''"${x}"'') cfg.trustedInterfaces);

  tcpSet = portsToNftSet cfg.allowedTCPPorts cfg.allowedTCPPortRanges;
  udpSet = portsToNftSet cfg.allowedUDPPorts cfg.allowedUDPPortRanges;
in
{
  options.providers.firewall = {
    backend = lib.mkOption {
      type = lib.types.enum [ "nftables" ];
    };
  };

  config = lib.mkMerge [
    (lib.mkIf config.services.nftables.enable {
      # this module supplies an implementation for `providers.firewall`
      providers.firewall.backend = lib.mkDefault "nftables";
    })

    (lib.mkIf (cfg.enable && cfg.backend == "nftables") {
      services.nftables.tables.finix-fw = {
        family = "inet";
        content = ''
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
        '';
      };
    })
  ];
}
