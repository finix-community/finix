{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.victorialogs;
in
{
  options.services.victorialogs = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [victorialogs](${pkgs.victorialogs.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.victorialogs;
      defaultText = lib.literalExpression "pkgs.victorialogs";
      description = ''
        The package to use for `victorialogs`.
      '';
    };

    httpListenAddr = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.submodule {
          options = {
            address = lib.mkOption {
              type = with lib.types; nullOr str;
              default = null;
              example = "127.0.0.1";
              description = ''
                The address to listen on, or `null` to listen on all IPv4 addresses.

                ::: {.note}
                IPv6 addresses must be enclosed in brackets and require `-enableTCP6` in
                {option}`services.victorialogs.extraArgs`.
                :::
              '';
            };

            port = lib.mkOption {
              type = lib.types.port;
              default = 9428;
              description = ''
                The port to listen on.
              '';
            };
          };
        }
      );
      default = { };
      description = ''
        The address `victorialogs` listens on for ingestion and queries.

        Additional addresses, including Unix domain sockets, can be added with `-httpListenAddr` in
        {option}`services.victorialogs.extraArgs`.
      '';
    };

    retentionPeriod = lib.mkOption {
      type = lib.types.str;
      default = "7d";
      example = "60d";
      description = ''
        How long to keep logs before they are deleted. Supported suffixes are `s`, `h`, `d`, `w`, `M`,
        and `y`, a value without a suffix is counted in months. The minimum is `1d`.
      '';
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/victorialogs";
      description = ''
        The directory used to store all `victorialogs` data.

        ::: {.note}
        If left as the default value this directory will automatically be created on
        service activation, otherwise you are responsible for ensuring the directory exists
        with appropriate ownership and permissions before the `victorialogs` service starts.
        :::
      '';
    };

    extraArgs = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      example = [
        "-retention.maxDiskSpaceUsageBytes=50GiB"
        "-syslog.listenAddr.udp=:514"
      ];
      description = ''
        Additional arguments to pass to `victorialogs`. See [upstream documentation](https://docs.victoriametrics.com/victorialogs/#list-of-command-line-flags)
        for additional details.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "victorialogs";
      description = ''
        User account under which `victorialogs` runs.

        ::: {.note}
        If left as the default value this user will automatically be created
        on system activation, otherwise you are responsible for
        ensuring the user exists before the `victorialogs` service starts.
        :::
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "victorialogs";
      description = ''
        Group account under which `victorialogs` runs.

        ::: {.note}
        If left as the default value this group will automatically be created
        on system activation, otherwise you are responsible for
        ensuring the group exists before the `victorialogs` service starts.
        :::
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.victorialogs.extraArgs = lib.mkBefore (
      [
        "-storageDataPath=${cfg.dataDir}"
        "-retentionPeriod=${cfg.retentionPeriod}"
      ]
      ++ lib.optionals (cfg.httpListenAddr != null) [
        "-httpListenAddr=${toString cfg.httpListenAddr.address}:${toString cfg.httpListenAddr.port}"
      ]
    );

    finit.services.victorialogs = {
      inherit (cfg) user group;

      description = "victorialogs log database";
      conditions = "service/syslogd/ready";
      command = "${lib.getExe cfg.package} " + lib.escapeShellArgs cfg.extraArgs;
      reload-signal = "none";
      log = { };
    }
    // lib.optionalAttrs (cfg.dataDir == "/var/lib/victorialogs") {
      state-dir = "victorialogs";
      state-dir-mode = "0700";
    };

    users.users = lib.optionalAttrs (cfg.user == "victorialogs") {
      victorialogs = {
        inherit (cfg) group;

        isSystemUser = true;
      };
    };

    users.groups = lib.optionalAttrs (cfg.group == "victorialogs") {
      victorialogs = { };
    };
  };
}
