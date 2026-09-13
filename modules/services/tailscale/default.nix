{
  config,
  pkgs,
  lib,
  options,
  ...
}:
let
  cfg = config.services.tailscale;

  tun = cfg.interfaceName != "userspace-networking";

  routingSysctls =
    lib.optionalAttrs
      (builtins.elem cfg.routingSysctls [
        "server"
        "both"
      ])
      {
        "net.ipv4.conf.all.forwarding" = lib.mkDefault true;
        "net.ipv6.conf.all.forwarding" = lib.mkDefault true;
      }
    //
      lib.optionalAttrs
        (builtins.elem cfg.routingSysctls [
          "client"
          "both"
        ])
        {
          "net.ipv4.conf.all.rp_filter" = lib.mkDefault 2;
          "net.ipv4.conf.default.rp_filter" = lib.mkDefault 2;
        };

  paramToString = v: if builtins.isBool v then lib.boolToString v else toString v;
  authKeyParams = lib.pipe cfg.authKeyParameters [
    (lib.filterAttrs (_: v: v != null))
    (lib.mapAttrsToList (k: v: "${k}=${paramToString v}"))
    (builtins.concatStringsSep "&")
    (params: if params != "" then "?${params}" else "")
  ];

  tailscaleUp = pkgs.writeShellScript "tailscale-up" ''
    ${cfg.package}/bin/tailscale up \
      ${
        lib.optionalString (
          cfg.authKeyFile != null
        ) "--auth-key=$(${pkgs.coreutils}/bin/cat ${cfg.authKeyFile})${lib.escapeShellArg authKeyParams}"
      } \
      ${lib.escapeShellArgs cfg.extraUpFlags}
  '';
in
{
  options.services.tailscale = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [tailscale](${pkgs.tailscale.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.tailscale;
      defaultText = lib.literalExpression "pkgs.tailscale";
      description = ''
        The package to use for `tailscale`.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 41641;
      description = ''
        UDP port to listen on for WireGuard and peer-to-peer traffic (0 = autoselect).
      '';
    };

    stateDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/tailscale";
      description = ''
        The directory used to store the daemon state (node key, preferences).

        ::: {.note}
        If left as the default value this directory will automatically be created
        on system activation, otherwise you are responsible for ensuring the
        directory exists with appropriate ownership and permissions before the
        `tailscaled` service starts.
        :::
      '';
    };

    interfaceName = lib.mkOption {
      type = lib.types.str;
      default = "tailscale0";
      description = ''
        The interface name for tunnel traffic. Use `"userspace-networking"` (beta)
        to not use TUN.
      '';
    };

    routingSysctls = lib.mkOption {
      type = lib.types.enum [
        "none"
        "client"
        "server"
        "both"
      ];
      default = "none";
      description = ''
        Enables sysctls required for subnet routers and exit nodes.

        `client` enables loose reverse-path filtering (for exit-node clients),
        `server` enables IPv4/IPv6 forwarding (for subnet routers and exit
        nodes), `both` enables both.
      '';
    };

    authKeyFile = lib.mkOption {
      type = with lib.types; nullOr path;
      default = null;
      example = "/run/secrets/tailscale_key";
      description = ''
        A file containing the auth key. If provided, `tailscale up` runs
        automatically once `tailscaled` is ready.
      '';
    };

    authKeyParameters = lib.mkOption {
      type = lib.types.submodule {
        options = {
          ephemeral = lib.mkOption {
            type = with lib.types; nullOr bool;
            default = null;
          };
          preauthorized = lib.mkOption {
            type = with lib.types; nullOr bool;
            default = null;
          };
          baseURL = lib.mkOption {
            type = with lib.types; nullOr str;
            default = null;
          };
        };
      };
      default = { };
      description = ''
        Extra parameters appended to the auth key.
        See <https://tailscale.com/kb/1215/oauth-clients#registering-new-nodes-using-oauth-credentials>
      '';
    };

    extraUpFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [
        "--ssh"
        "--advertise-exit-node"
      ];
      description = ''
        Extra flags passed to {command}`tailscale up`.
      '';
    };

    extraDaemonFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "--no-logs-no-support" ];
      description = ''
        Extra flags passed to {command}`tailscaled`.
      '';
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        boot.kernelModules = lib.optionals tun [ "tun" ];
        boot.kernel.sysctl = routingSysctls;

        environment.systemPackages = [ cfg.package ];

        finit.services.tailscaled = {
          description = "tailscale mesh VPN daemon";
          notify = "systemd";
          respawn = true;
          conditions = [
            "service/syslogd/ready"
            "net/route/default"
          ];
          path = [
            (dirOf config.security.wrapperDir)
            pkgs.iproute2
            pkgs.iptables
            pkgs.procps
            pkgs.getent
            pkgs.kmod
          ]
          ++ lib.optional config.programs.resolvconf.enable config.programs.resolvconf.package;
          command = lib.concatStringsSep " " (
            [
              "${cfg.package}/bin/tailscaled"
              "--state=${cfg.stateDir}/tailscaled.state"
              "--socket=/run/tailscale/tailscaled.sock"
              "--port=${toString cfg.port}"
              "--tun=${cfg.interfaceName}"
            ]
            ++ cfg.extraDaemonFlags
          );
          log = true;
        };

        finit.tasks.tailscale-up = lib.mkIf (cfg.authKeyFile != null || cfg.extraUpFlags != [ ]) {
          description = "tailscale up";
          conditions = [ "service/tailscaled/ready" ];
          command = "${tailscaleUp}";
          log = true;
        };

        finit.tmpfiles.rules = [
          "d /run/tailscale 0755 root root"
        ]
        ++ lib.optionals (cfg.stateDir == "/var/lib/tailscale") [
          "d ${cfg.stateDir} 0700 root root"
        ];
      }
      (lib.optionalAttrs (options ? services.dhcpcd) {
        services.dhcpcd.settings.denyinterfaces = lib.mkIf tun [ cfg.interfaceName ];
      })
    ]
  );
}
