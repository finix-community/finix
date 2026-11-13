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

  allowRules =
    iface: ports:
    let
      ifaceExpr = lib.optionalString (iface != null) ''iifname "${iface}" '';
      tcpSet = portsToNftSet ports.allowedTCPPorts ports.allowedTCPPortRanges;
      udpSet = portsToNftSet ports.allowedUDPPorts ports.allowedUDPPortRanges;
    in
    ''
      ${lib.optionalString (tcpSet != "") "${ifaceExpr}tcp dport { ${tcpSet} } accept"}
      ${lib.optionalString (udpSet != "") "${ifaceExpr}udp dport { ${udpSet} } accept"}
    '';
in
{
  options.providers.firewall = {
    backend = lib.mkOption {
      type = lib.types.enum [ "nftables" ];
    };
  };

  config = lib.mkIf (cfg.backend == "nftables") {
    # piggyback off nixos table names for compatibility with nixos-firewall-tool
    services.nftables.tables.nixos-fw = {
      family = "inet";
      content = ''
        # ports opened at runtime by `nixos-firewall-tool open`, discarded on reload
        set temp-ports {
          comment "temporarily opened ports"
          type inet_proto . inet_service
          flags interval
          auto-merge
        }

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
          ${allowRules null cfg}
          ${lib.concatStrings (lib.mapAttrsToList allowRules nftCfg.interfaces)}

          meta l4proto . th dport @temp-ports accept
        }
      '';
    };
  };
}
