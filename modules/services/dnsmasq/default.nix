{
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.services.dnsmasq;
  stateDir = "/var/lib/dnsmasq";
  # True values are just put as `name` instead of `name=true`, and false values
  # are turned to comments (false values are expected to be overrides e.g.
  # lib.mkForce)
  formatKeyValue =
    name: value:
    if value == true then
      name
    else if value == false then
      "# setting `${name}` explicitly set to false"
    else
      lib.generators.mkKeyValueDefault { } "=" name value;

  settingsFormat = pkgs.formats.keyValue {
    mkKeyValue = formatKeyValue;
    listsAsDuplicateKeys = true;
  };
  dnsmasqConf = settingsFormat.generate "dnsmasq.conf" cfg.settings;
in
{
  options = {
    services.dnsmasq = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to run [dnsmasq](${pkgs.dnsmasq.meta.homepage}) as a system service.
        '';
      };

      resolveLocalQueries = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether [dnsmasq](${pkgs.dnsmasq.meta.homepage}) should resolve local queries using [resolvconf](${pkgs.resolvconf.meta.homepage}).
        '';
      };

      settings = lib.mkOption {
        type = lib.types.submodule {

          freeformType = settingsFormat.type;

          options.server = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            example = [
              "8.8.8.8"
              "8.8.4.4"
            ];
            description = ''
              The DNS servers which [dnsmasq](${pkgs.dnsmasq.meta.homepage}) should query.
            '';
          };

          options.port = lib.mkOption {
            type = lib.types.port;
            default = 53;
            description = "The port number [dnsmasq](${pkgs.dnsmasq.meta.homepage}) will listen on.";
          };

        };
        default = { };
        description = ''
          Configuration of [dnsmasq]((${pkgs.dnsmasq.meta.homepage})). Lists get added one value per line (empty
          lists and false values don't get added, though false values get
          turned to comments).
        '';
        example = lib.literalExpression ''
          {
            domain-needed = true;
            dhcp-range = [ "192.168.0.2,192.168.0.254" ];
          }
        '';
      };

      configFile = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        default = dnsmasqConf;
        defaultText = lib.literalExpression "Path of [dnsmasq]((${pkgs.dnsmasq.meta.homepage})) config file.";
        description = ''
          Path to the configuration file of [dnsmasq]((${pkgs.dnsmasq.meta.homepage})).
        '';
      };

      package = lib.mkPackageOption pkgs "dnsmasq" { };
    };
  };
  config = lib.mkIf cfg.enable {
    services.dnsmasq = {
      settings = {
        conf-file = lib.mkDefault (
          lib.optional (cfg.resolveLocalQueries && !cfg.settings.no-resolv) "/etc/dnsmasq-conf.conf"
        );
        dhcp-leasefile = lib.mkDefault "${stateDir}/dnsmasq.leases";
        resolv-file = lib.mkDefault (
          lib.optional (cfg.resolveLocalQueries && !cfg.settings.no-resolv) "/etc/dnsmasq-resolv.conf"
        );
      };
    };

    programs.resolvconf.settings =
      lib.mkIf (!cfg.settings.no-resolv) {
        dnsmasq_conf = "/etc/dnsmasq-conf.conf";
        dnsmasq_resolv = "/etc/dnsmasq-resolv.conf";
      }
      // lib.optionalAttrs cfg.resolveLocalQueries {
        name_servers = "127.0.0.1";
      }
      // lib.optionalAttrs config.services.dbus.enable {
        enable-dbus = true;
      };

    users.users.dnsmasq = {
      isSystemUser = true;
      group = config.users.groups.dnsmasq.name;
      description = "Dnsmasq daemon user";
    };
    users.groups.dnsmasq = { };

    services.dbus.packages = lib.optional (config.services.dbus.enable) cfg.package;

    finit.tmpfiles.rules = [
      "d ${stateDir} 0755 ${config.users.users.dnsmasq.name} root - -"
      "f ${stateDir}/dnsmasq.leases 0644 ${config.users.users.dnsmasq.name} root -"
    ]
    ++ lib.optional (cfg.resolveLocalQueries && !cfg.settings.no-resolv) [
      "f /etc/dnsmasq-conf.conf 0644 root root - -"
      "f /etc/dnsmasq-resolv.conf 0644 root root - -"
    ];

    finit.services.dnsmasq = {
      description = "Dnsmasq Daemon";
      conditions = [
        "service/syslogd/running"
        "net/lo/up"
      ]
      ++ lib.optionals (config.services.dbus.enable) [ "service/dbus/ready" ]
      ++ lib.optionals (cfg.settings ? interface) (
        map (interface: "net/${interface}/up") cfg.settings.interface
      );

      # TODO: check if PID could be a valid notification for this service.
      #notify = if config.services.dbus.enable then "systemd" else "none";

      pre = pkgs.writeShellScript "dnsmasq-pre.sh" ''
        ${cfg.package}/bin/dnsmasq --test -C ${cfg.configFile}
      '';

      command = lib.escapeShellArgs (
        [
          "${cfg.package}/bin/dnsmasq"
          "-k"
        ]
        ++ lib.optionals config.services.dbus.enable [ "--enable-dbus" ]
        ++ [
          "--user=${config.users.users.dnsmasq.name}"
          "-C"
          "${cfg.configFile}"
        ]
      );

      respawn = true;
    };
  };
}
