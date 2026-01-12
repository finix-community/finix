{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.ifupdown-ng;

  format = pkgs.formats.keyValue {
    mkKeyValue = lib.generators.mkKeyValueDefault { } " = ";
  };

  multiValueType = with lib.types; nullOr (coercedTo str lib.singleton (listOf str));
in
{
  options.programs.ifupdown-ng = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [ifupdown-ng](https://github.com/ifupdown-ng/ifupdown-ng).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./package.nix { };
      defaultText = lib.literalExpression "pkgs.ifupdown-ng";
      description = ''
        The package to use for `ifupdown-ng`.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.
      '';
    };

    extraArgs = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      example = [
        "--timeout"
        "60"
      ];
      description = ''
        Additional arguments to pass to `ifupdown-ng`. See {manpage}`ifupdown-ng(8)`
        for additional details.
      '';
    };

    settings = lib.mkOption {
      type = format.type;
      default = { };
      description = ''
        `ifupdown-ng` configuration. See {manpage}`ifupdown-ng.conf(5)`
        for additional details.
      '';
    };

    auto = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      example = [
        "eth0"
        "br0"
      ];
      description = ''
        Designates interfaces that should be automatically configured by the system when appropriate.
      '';
    };

    iface = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          freeformType =
            with lib.types;
            attrsOf (oneOf [
              bool
              str
              (listOf str)
            ]);

          options = {
            address = lib.mkOption {
              type = multiValueType;
              default = null;
              example = [
                "203.0.113.2/24"
                "2001:db8::2/64"
              ];
              description = "Associates an IPv4 or IPv6 address in CIDR notation with the parent interface.";
            };

            gateway = lib.mkOption {
              type = multiValueType;
              default = null;
              example = [
                "203.0.113.1"
                "2001:db8::1"
              ];
              description = "Associates an IPv4 or IPv6 address with the parent interface for use as a default route (gateway).";
            };

            use = lib.mkOption {
              type = multiValueType;
              default = null;
              example = [
                "dhcp"
                "bridge"
              ];
              description = ''
                Designates that an executor should be used. See [EXECUTORS](https://manpages.debian.org/unstable/ifupdown-ng/interfaces.5#EXECUTORS)
                section for more information on executors.
              '';
            };

            requires = lib.mkOption {
              type = multiValueType;
              default = null;
              example = [
                "eth0"
                "eth1"
              ];
              description = ''
                Designates one or more required interfaces that must be brought up before configuration of
                the parent interface. Interfaces associated with the parent are taken down at the same time
                as the parent.
              '';
            };
          };
        }
      );
      default = { };
      example = lib.literalExpression ''
        {
          eth0 = {
            address = [ "203.0.113.2/24" "2001:db8::2/64" ];
            gateway = "203.0.113.1";
            use = "dhcp";
          };
          br0 = {
            address = "10.0.0.1/24";
            bridge-ports = "eth0 eth1";
            bridge-stp = true;
          };
        }
      '';
      description = ''
        `/etc/network/interfaces` configuration. See {manpage}`interfaces(5)`
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.ifupdown-ng.extraArgs = [ "-a" ] ++ lib.optionals cfg.debug [ "-v" ];

    environment.systemPackages = [ cfg.package ];

    environment.etc."network/ifupdown-ng.conf".source = format.generate "ifupdown-ng.conf" cfg.settings;
    environment.etc."network/interfaces".text =
      let
        # keys whose list values should be joined with spaces (single line)
        # rather than producing duplicate keys (multiple lines)
        spaceSeparatedKeys = [ "requires" ];

        # prepare attrs for toKeyValue generation:
        # - filter out null values and false bools
        # - convert true bools to "" (key only, no value)
        # - join space-separated keys into single string
        prepareAttrs =
          attrs:
          lib.mapAttrs (
            k: v:
            if v == true then
              ""
            else if lib.elem k spaceSeparatedKeys && lib.isList v then
              lib.concatStringsSep " " v
            else
              v
          ) (lib.filterAttrs (k: v: v != null && v != false) attrs);

        toKeyValue' = lib.generators.toKeyValue {
          mkKeyValue = k: v: if v == "" then "  ${k}" else "  ${k} ${v}";
          listsAsDuplicateKeys = true;
        };

        autoSection = lib.concatMapStringsSep "\n" (name: "auto ${name}") cfg.auto;
        ifaceBlocks = lib.mapAttrsToList (
          name: iface: "iface ${name}\n${lib.removeSuffix "\n" (toKeyValue' (prepareAttrs iface))}"
        ) cfg.iface;
      in
      lib.concatStringsSep "\n\n" (lib.optional (cfg.auto != [ ]) autoSection ++ ifaceBlocks);

    finit.tasks.ifupdown-ng = {
      description = "bring up network interfaces";
      log = true;
      command =
        "${cfg.package}/bin/ifup -E ${cfg.package}/libexec/ifupdown-ng "
        + lib.escapeShellArgs cfg.extraArgs;
      conditions = [
        "service/syslogd/ready"
      ]
      ++ lib.map (iface: "net/${iface}/exist") cfg.auto;
    };
  };
}
