{
  config,
  lib,
  ...
}:
let
  cfg = config.providers.firewall;

  refuseRules =
    if cfg.rejectPackets then
      ''
        -A finix-fw-refuse -p tcp ! --syn -j REJECT --reject-with tcp-reset
        -A finix-fw-refuse -j REJECT
      ''
    else
      ''
        -A finix-fw-refuse -j DROP
      '';

  commonRules = ''
    *filter
    :INPUT DROP [0:0]
    :FORWARD DROP [0:0]
    :OUTPUT ACCEPT [0:0]
    -N finix-fw-accept
    -N finix-fw-refuse
    -N finix-fw-log-refuse
    -N finix-fw
    -A finix-fw-accept -j ACCEPT
    ${refuseRules}
    -A finix-fw-log-refuse -j finix-fw-refuse
    ${lib.concatMapStrings (iface: ''
      -A finix-fw -i ${iface} -j finix-fw-accept
    '') cfg.trustedInterfaces}
    -A finix-fw -m conntrack --ctstate ESTABLISHED,RELATED -j finix-fw-accept
    ${lib.concatMapStrings (port: ''
      -A finix-fw -p tcp --dport ${toString port} -j finix-fw-accept
    '') cfg.allowedTCPPorts}
    ${lib.concatMapStrings ({ from, to }: ''
      -A finix-fw -p tcp --dport ${toString from}:${toString to} -j finix-fw-accept
    '') cfg.allowedTCPPortRanges}
    ${lib.concatMapStrings (port: ''
      -A finix-fw -p udp --dport ${toString port} -j finix-fw-accept
    '') cfg.allowedUDPPorts}
    ${lib.concatMapStrings ({ from, to }: ''
      -A finix-fw -p udp --dport ${toString from}:${toString to} -j finix-fw-accept
    '') cfg.allowedUDPPortRanges}
  '';
in
{
  options.providers.firewall = {
    backend = lib.mkOption {
      type = lib.types.enum [ "iptables" ];
    };
  };

  config = lib.mkMerge [
    (lib.mkIf config.services.iptables.enable {
      # this module supplies an implementation for `providers.firewall`
      providers.firewall.backend = lib.mkDefault "iptables";
    })

    (lib.mkIf (cfg.enable && cfg.backend == "iptables") {
      services.iptables.rulesetV4 =
        commonRules
        + lib.optionalString cfg.allowPing ''
          -A finix-fw -p icmp --icmp-type echo-request -j finix-fw-accept
        ''
        + ''
          -A finix-fw -j finix-fw-log-refuse
          -A INPUT -j finix-fw
          COMMIT
        '';

      services.iptables.rulesetV6 =
        commonRules
        + lib.optionalString cfg.allowPing ''
          -A finix-fw -p icmpv6 --icmpv6-type echo-request -j finix-fw-accept
        ''
        + ''
          -A finix-fw -j finix-fw-log-refuse
          -A INPUT -j finix-fw
          COMMIT
        '';
    })
  ];
}
