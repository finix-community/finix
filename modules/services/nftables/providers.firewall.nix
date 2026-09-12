{
  config,
  lib,
  ...
}:
let
  cfg = config.providers.firewall;
  nftCfg = config.services.nftables;

  portsToNftSet =
    ports: portRanges:
    lib.concatStringsSep ", " (
      map toString ports ++ map ({ from, to }: "${toString from}-${toString to}") portRanges
    );

  ifaceSet = lib.concatMapStringsSep ", " (iface: ''"${iface}"'') nftCfg.trustedInterfaces;

  tcpSet = portsToNftSet cfg.allowedTCPPorts cfg.allowedTCPPortRanges;
  udpSet = portsToNftSet cfg.allowedUDPPorts cfg.allowedUDPPortRanges;
in
{
  options.providers.firewall = {
    backend = lib.mkOption {
      type = lib.types.enum [ "nftables" ];
    };
  };

  config = lib.mkIf (cfg.backend == "nftables") {
    # named after the table NixOS installs, for consistency with the tooling and
    # documentation that refers to `inet nixos-fw`.
    services.nftables.tables.nixos-fw = {
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

          ${lib.optionalString nftCfg.rejectPackets ''
            meta l4proto tcp reject with tcp reset
            reject
          ''}
        }

        chain input-allow {
          ${lib.optionalString (tcpSet != "") "tcp dport { ${tcpSet} } accept"}
          ${lib.optionalString (udpSet != "") "udp dport { ${udpSet} } accept"}
        }
      '';
    };
  };
}
