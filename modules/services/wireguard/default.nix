{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) types;
  cfg = config.services.wireguard;

  nsWrap =
    cmd: src: dst:
    let
      nsList = lib.filter (ns: ns != null) [
        src
        dst
      ];
      ns = lib.last nsList;
    in
    if (lib.length nsList > 0 && ns != "init") then ''ip netns exec "${ns}" "${cmd}"'' else cmd;

  mkInterfaceTask =
    name: values:
    let
      src = values.socketNamespace;
      dst = values.interfaceNamespace;
      ipPreMove = nsWrap "ip" src null;
      ipPostMove = nsWrap "ip" src dst;
      wg = nsWrap (lib.getExe cfg.package) src dst;
      ns = if dst == "init" then "1" else dst;
    in
    lib.nameValuePair "wireguard-${name}" {
      description = "WireGuard tunnel ${name}";

      conditions = [
        "service/syslogd/ready"
        "task/modprobe/success"
      ];

      environment.DEVICE = name;
      remain-after-exit = true;

      command = pkgs.writeShellScript "wireguard-${name}-start" (
        lib.concatStringsSep "\n" (
          [
            "set -e"
            values.preSetup
            ''${ipPreMove} link add dev "${name}" type ${cfg.kernelModule}''
          ]
          ++ lib.optional (
            values.interfaceNamespace != null && values.interfaceNamespace != values.socketNamespace
          ) ''${ipPreMove} link set "${name}" netns "${ns}"''
          ++ lib.optional (values.mtu != null) ''${ipPostMove} link set "${name}" mtu ${toString values.mtu}''
          ++ map (ip: ''${ipPostMove} address add "${ip}" dev "${name}"'') values.ips
          ++ [
            (lib.concatStringsSep " " (
              [ ''${wg} set "${name}" private-key "${values.privateKeyFile}"'' ]
              ++ lib.optional (values.listenPort != null) ''listen-port "${toString values.listenPort}"''
              ++ lib.optional (values.fwMark != null) ''fwmark "${values.fwMark}"''
              ++ lib.mapAttrsToList (k: v: ''${lib.toLower k} "${toString v}"'') (
                lib.filterAttrs (_: v: v != null) values.extraOptions
              )
            ))
            ''${ipPostMove} link set up dev "${name}"''
            values.postSetup
          ]
        )
      );

      exec-stop-post = pkgs.writeShellScript "wireguard-${name}-stop" ''
        ${values.preShutdown}
        ${ipPostMove} link del dev "${name}"
        ${values.postShutdown}
      '';

      path = [
        pkgs.iproute2
        cfg.package
      ];
    };

  mkPeerUnits =
    interfaceName: interface: peer:
    let
      src = interface.socketNamespace;
      dst = interface.interfaceNamespace;

      ip = nsWrap "ip" src dst;
      wg = nsWrap (lib.getExe cfg.package) src dst;

      refreshSeconds =
        if peer.dynamicEndpointRefreshSeconds != null then
          peer.dynamicEndpointRefreshSeconds
        else
          interface.dynamicEndpointRefreshSeconds;
      refreshEnabled = refreshSeconds != 0;

      wgSetup = lib.concatStringsSep " " (
        [ ''${wg} set "${interfaceName}" peer "${peer.publicKey}"'' ]
        ++ lib.optional (peer.presharedKeyFile != null) ''preshared-key "${peer.presharedKeyFile}"''
        ++ lib.optional (peer.endpoint != null) ''endpoint "${peer.endpoint}"''
        ++ lib.optional (
          peer.persistentKeepalive != null
        ) ''persistent-keepalive "${toString peer.persistentKeepalive}"''
        ++ lib.optional (
          peer.allowedIPs != [ ]
        ) ''allowed-ips "${lib.concatStringsSep "," peer.allowedIPs}"''
      );

      routeSetup = lib.optionalString interface.allowedIPsAsRoutes (
        lib.concatMapStringsSep "\n" (
          allowedIP:
          ''${ip} route replace "${allowedIP}" dev "${interfaceName}" table "${interface.table}"''
          + lib.optionalString (interface.metric != null) " metric ${toString interface.metric}"
        ) peer.allowedIPs
      );

      routeDestroy = lib.optionalString interface.allowedIPsAsRoutes (
        lib.concatMapStringsSep "\n" (
          allowedIP: ''${ip} route delete "${allowedIP}" dev "${interfaceName}" table "${interface.table}"''
        ) peer.allowedIPs
      );

      unit = {
        description =
          "WireGuard peer ${interfaceName} - ${peer.name}"
          + lib.optionalString (peer.name != peer.publicKey) " (${peer.publicKey})";

        conditions = [ "task/wireguard-${interfaceName}/success" ];

        environment = {
          DEVICE = interfaceName;
          WG_ENDPOINT_RESOLUTION_RETRIES = "infinity";
        };

        command = pkgs.writeShellScript "wireguard-${interfaceName}-peer-${peer.name}-start" ''
          set -e
          ${wgSetup}
          ${routeSetup}
          ${lib.optionalString refreshEnabled ''
            # Re-execute 'wg' periodically to notice DNS / hostname changes.
            # Note this will not time out on transient DNS failures such as DNS names
            # because we have set 'WG_ENDPOINT_RESOLUTION_RETRIES=infinity'.
            # Also note that 'wg' limits its maximum retry delay to 20 seconds as of writing.
            while ${wgSetup}; do
              ${config.programs.coreutils.package}/bin/sleep "${toString refreshSeconds}"
            done
          ''}
        '';

        exec-stop-post = pkgs.writeShellScript "wireguard-${interfaceName}-peer-${peer.name}-stop" ''
          ${wg} set "${interfaceName}" peer "${peer.publicKey}" remove
          ${routeDestroy}
        '';

        path = [
          pkgs.iproute2
          cfg.package
        ];
      };
    in
    {
      tasks = lib.optionalAttrs (!refreshEnabled) {
        "wireguard-${interfaceName}-peer-${peer.name}" = unit // {
          remain-after-exit = true;
        };
      };

      services = lib.optionalAttrs refreshEnabled {
        "wireguard-${interfaceName}-peer-${peer.name}" = unit // {
          # Restart if the service exits (e.g. when wireguard gives up after "Name or service not known" dns failures):
          respawn = true;
          restart-sec =
            if peer.dynamicEndpointRefreshRestartSeconds != null then
              peer.dynamicEndpointRefreshRestartSeconds
            else
              refreshSeconds;
        };
      };
    };
in
{
  options.services.wireguard = {
    enable = lib.mkOption {
      description = ''
        Whether to enable WireGuard.
      '';
      type = types.bool;
      default = false;
      example = true;
    };

    package = lib.mkOption {
      type = types.package;
      default = pkgs.wireguard-tools;
      example = pkgs.amneziawg-tools;
    };

    kernelModule = lib.mkOption {
      type = types.str;
      default = "wireguard";
      example = "amneziawg";
    };

    kernelModulePackage = lib.mkOption {
      type = types.nullOr types.package;
      default =
        if lib.versionOlder config.boot.kernelPackages.kernel.version "5.6" then
          config.boot.kernelPackages.wireguard
        else
          null;
      example = config.boot.kernelPackages.amneziawg;
    };

    interfaces = lib.mkOption {
      description = ''
        WireGuard interfaces.
      '';
      default = { };
      example = {
        wg0 = {
          ips = [ "192.168.20.4/24" ];
          privateKeyFile = "/private/wireguard_key";
          peers = [
            {
              allowedIPs = [ "192.168.20.1/32" ];
              publicKey = "xTIBA5rboUvnH4htodjb6e697QjLERt1NAB4mZqp8Dg=";
              endpoint = "demo.wireguard.io:12913";
            }
          ];
        };
      };
      type = types.attrsOf (
        types.submodule (
          { ... }:
          {
            options = {
              ips = lib.mkOption {
                example = [ "192.168.2.1/24" ];
                default = [ ];
                type = types.listOf types.str;
                description = "The IP addresses of the interface.";
              };

              privateKeyFile = lib.mkOption {
                example = "/private/wireguard_key";
                type = types.nullOr types.str;
                default = null;
                description = ''
                  Private key file as generated by {command}`wg genkey`.
                '';
              };

              listenPort = lib.mkOption {
                default = null;
                type = types.nullOr types.int;
                example = 51820;
                description = ''
                  16-bit port for listening. Optional; if not specified,
                  automatically generated based on interface name.
                '';
              };

              preSetup = lib.mkOption {
                example = lib.literalExpression ''"''${pkgs.iproute2}/bin/ip netns add foo"'';
                default = "";
                type = types.coercedTo (types.listOf types.str) (types.concatStringsSep "\n") types.lines;
                description = ''
                  Commands called at the start of the interface setup.
                '';
              };

              postSetup = lib.mkOption {
                example = lib.literalExpression ''
                  '''printf "nameserver 10.200.100.1" | ''${pkgs.openresolv}/bin/resolvconf -a wg0 -m 0'''
                '';
                default = "";
                type = types.coercedTo (types.listOf types.str) (types.concatStringsSep "\n") types.lines;
                description = "Commands called at the end of the interface setup.";
              };

              preShutdown = lib.mkOption {
                example = lib.literalExpression ''"''${pkgs.iproute2}/bin/ip netns del foo"'';
                default = "";
                type = types.coercedTo (types.listOf types.str) (types.concatStringsSep "\n") types.lines;
                description = ''
                  Commands called before shutting down the interface.
                '';
              };

              postShutdown = lib.mkOption {
                example = lib.literalExpression ''"''${pkgs.openresolv}/bin/resolvconf -d wg0"'';
                default = "";
                type = types.coercedTo (types.listOf types.str) (types.concatStringsSep "\n") types.lines;
                description = "Commands called after shutting down the interface.";
              };

              table = lib.mkOption {
                default = "main";
                type = types.str;
                description = ''
                  The kernel routing table to add this interface's
                  associated routes to. Setting this is useful for e.g. policy routing
                  ("ip rule") or virtual routing and forwarding ("ip vrf"). Both
                  numeric table IDs and table names (/etc/rt_tables) can be used.
                  Defaults to "main".
                '';
              };

              peers = lib.mkOption {
                default = [ ];
                description = "Peers linked to the interface.";
                type = types.listOf (
                  types.submodule (
                    { config, ... }: {
                      options = {
                        name = lib.mkOption {
                          default = lib.replaceStrings [ "/" "+" "=" ] [ "_" "-" "" ] config.publicKey;
                          defaultText = lib.literalExpression "publicKey";
                          example = "bernd";
                          type = types.str;
                          description = "Name used to derive peer unit name.";
                        };

                        publicKey = lib.mkOption {
                          example = "xTIBA5rboUvnH4htodjb6e697QjLERt1NAB4mZqp8Dg=";
                          type = types.singleLineStr;
                          description = "The base64 public key of the peer.";
                        };

                        presharedKeyFile = lib.mkOption {
                          default = null;
                          example = "/private/wireguard_psk";
                          type = types.nullOr types.str;
                          description = ''
                            File pointing to preshared key as generated by {command}`wg genpsk`.
                            Optional, and may be omitted. This option adds an additional layer of
                            symmetric-key cryptography to be mixed into the already existing
                            public-key cryptography, for post-quantum resistance.
                          '';
                        };

                        allowedIPs = lib.mkOption {
                          example = [
                            "10.192.122.3/32"
                            "10.192.124.1/24"
                          ];
                          type = types.listOf types.str;
                          description = ''
                            List of IP (v4 or v6) addresses with CIDR masks from
                            which this peer is allowed to send incoming traffic and to which
                            outgoing traffic for this peer is directed. The catch-all 0.0.0.0/0 may
                            be specified for matching all IPv4 addresses, and ::/0 may be specified
                            for matching all IPv6 addresses.'';
                        };

                        endpoint = lib.mkOption {
                          default = null;
                          example = "demo.wireguard.io:12913";
                          type = types.nullOr types.str;
                          description = ''
                            Endpoint IP or hostname of the peer, followed by a colon,
                            and then a port number of the peer.

                            Warning for endpoints with changing IPs:
                            The WireGuard kernel side cannot perform DNS resolution.
                            Thus DNS resolution is done once by the `wg` userspace
                            utility, when setting up WireGuard. Consequently, if the IP address
                            behind the name changes, WireGuard will not notice.
                            This is especially common for dynamic-DNS setups, but also applies to
                            any other DNS-based setup.
                            If you do not use IP endpoints, you likely want to set
                            {option}`services.wireguard.dynamicEndpointRefreshSeconds`
                            to refresh the IPs periodically.
                          '';
                        };

                        dynamicEndpointRefreshSeconds = lib.mkOption {
                          default = null;
                          defaultText = lib.literalExpression "config.services.wireguard.interfaces.<name>.dynamicEndpointRefreshSeconds";
                          example = 5;
                          type = types.nullOr types.int;
                          description = ''
                            Periodically re-execute the `wg` utility every
                            this many seconds in order to let WireGuard notice DNS / hostname
                            changes.

                            Setting this to `0` disables periodic reexecution.
                          '';
                        };

                        dynamicEndpointRefreshRestartSeconds = lib.mkOption {
                          default = null;
                          example = 5;
                          type = types.nullOr types.ints.unsigned;
                          description = ''
                            When the dynamic endpoint refresh that is configured via
                            dynamicEndpointRefreshSeconds exits (likely due to a failure),
                            restart that service after this many seconds.

                            If set to `null` the value of
                            {option}`services.wireguard.dynamicEndpointRefreshSeconds`
                            will be used as the default.
                          '';
                        };

                        persistentKeepalive = lib.mkOption {
                          default = null;
                          type = types.nullOr types.int;
                          example = 25;
                          description = ''
                            This is optional and is by default off, because most
                            users will not need it. It represents, in seconds, between 1 and 65535
                            inclusive, how often to send an authenticated empty packet to the peer,
                            for the purpose of keeping a stateful firewall or NAT mapping valid
                            persistently. For example, if the interface very rarely sends traffic,
                            but it might at anytime receive traffic from a peer, and it is behind
                            NAT, the interface might benefit from having a persistent keepalive
                            interval of 25 seconds; however, most users will not need this.'';
                        };
                      };
                    }
                  )
                );
              };

              allowedIPsAsRoutes = lib.mkOption {
                example = false;
                default = true;
                type = types.bool;
                description = ''
                  Determines whether to add allowed IPs as routes or not.
                '';
              };

              socketNamespace = lib.mkOption {
                default = null;
                type = types.nullOr types.str;
                example = "container";
                description = ''
                  The pre-existing network namespace in which the
                  WireGuard interface is created, and which retains the socket even if the
                  interface is moved via {option}`interfaceNamespace`. When
                  `null`, the interface is created in the init namespace.
                  See [documentation](https://www.wireguard.com/netns/).
                '';
              };

              interfaceNamespace = lib.mkOption {
                default = null;
                type = types.nullOr types.str;
                example = "init";
                description = ''
                  The pre-existing network namespace the WireGuard
                  interface is moved to. The special value `init` means
                  the init namespace. When `null`, the interface is not
                  moved.
                  See [documentation](https://www.wireguard.com/netns/).
                '';
              };

              fwMark = lib.mkOption {
                default = null;
                type = types.nullOr types.str;
                example = "0x6e6978";
                description = ''
                  Mark all wireguard packets originating from
                  this interface with the given firewall mark. The firewall mark can be
                  used in firewalls or policy routing to filter the wireguard packets.
                  This can be useful for setup where all traffic goes through the
                  wireguard tunnel, because the wireguard packets need to be routed
                  differently.
                '';
              };

              mtu = lib.mkOption {
                default = null;
                type = types.nullOr types.int;
                example = 1280;
                description = ''
                  Set the maximum transmission unit in bytes for the wireguard
                  interface. Beware that the wireguard packets have a header that may
                  add up to 80 bytes to the mtu. By default, the MTU is (1500 - 80) =
                  1420. However, if the MTU of the upstream network is lower, the MTU
                  of the wireguard network has to be adjusted as well.
                '';
              };

              metric = lib.mkOption {
                default = null;
                type = types.nullOr types.int;
                example = 700;
                description = ''
                  Set the metric of routes related to this Wireguard interface.
                '';
              };

              extraOptions = lib.mkOption {
                type = types.submodule {
                  freeformType = types.attrsOf (
                    types.nullOr (
                      types.oneOf [
                        types.str
                        types.int
                      ]
                    )
                  );
                };
                default = { };
                example = {
                  Jc = 5;
                };
                description = ''
                  Extra options passed to {command}`wg set` for this interface,
                  with the key lowercased. Options set to `null` are skipped.
                  Used by implementations such as AmneziaWG to set their
                  additional parameters.
                '';
              };

              dynamicEndpointRefreshSeconds = lib.mkOption {
                default = 0;
                example = 300;
                type = types.int;
                description = ''
                  Periodically refresh the endpoint hostname or address for all peers.
                  Allows WireGuard to notice DNS and IPv4/IPv6 connectivity changes.
                  This option can be set or overridden for individual peers.

                  Setting this to `0` disables periodic refresh.
                '';
              };
            };
          }
        )
      );
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = (
      lib.attrValues (
        lib.mapAttrs (name: value: {
          assertion = (value.privateKeyFile != null);
          message = "services.wireguard.interfaces.${name}.privateKeyFile must be set.";
        }) cfg.interfaces
      )
    );

    boot.extraModulePackages = lib.optional (cfg.kernelModulePackage != null) cfg.kernelModulePackage;

    boot.kernelModules = [ cfg.kernelModule ];

    environment.systemPackages = [ cfg.package ];

    finit =
      let
        interfaces = lib.mapAttrsToList (
          interfaceName: interface:
          let
            peers = map (peer: mkPeerUnits interfaceName interface peer) interface.peers;
          in
          {
            tasks = [
              (lib.mapAttrs' mkInterfaceTask {
                ${interfaceName} = interface;
              })
            ]
            ++ map (units: units.tasks) peers;

            services = map (units: units.services) peers;
          }
        ) cfg.interfaces;
      in
      {
        tasks = lib.mkMerge (lib.concatMap (interface: interface.tasks) interfaces);
        services = lib.mkMerge (lib.concatMap (interface: interface.services) interfaces);
      };
  };
}
