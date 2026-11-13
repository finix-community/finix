{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.vector;

  format = pkgs.formats.toml { };
  configFile = format.generate "vector.toml" cfg.settings;
in
{
  options.services.vector = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [vector](${pkgs.vector.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.vector;
      defaultText = lib.literalExpression "pkgs.vector";
      description = ''
        The package to use for `vector`.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.
      '';
    };

    settings = lib.mkOption {
      inherit (format) type;

      default = { };
      description = ''
        `vector` configuration. See [upstream documentation](https://vector.dev/docs/reference/configuration/)
        for additional details.
      '';
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/vector";
      description = ''
        The directory used to store all `vector` data, such as file checkpoints and disk buffers.

        ::: {.note}
        If left as the default value this directory will automatically be created on
        service activation, otherwise you are responsible for ensuring the directory exists
        with appropriate ownership and permissions before the `vector` service starts.
        :::
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "vector";
      description = ''
        User account under which `vector` runs.

        ::: {.note}
        If left as the default value this user will automatically be created
        on system activation, otherwise you are responsible for
        ensuring the user exists before the `vector` service starts.
        :::
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "vector";
      description = ''
        Group account under which `vector` runs.

        ::: {.note}
        If left as the default value this group will automatically be created
        on system activation, otherwise you are responsible for
        ensuring the group exists before the `vector` service starts.
        :::
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.vector.settings.data_dir = cfg.dataDir;

    environment.etc."vector/vector.toml".source = configFile;

    finit.services.vector = {
      inherit (cfg) user group;

      description = "observability data pipeline";
      conditions = "service/syslogd/ready";
      command = "${lib.getExe cfg.package} --config-toml /etc/vector/vector.toml";
      log = { };

      environment = lib.optionalAttrs cfg.debug {
        VECTOR_LOG = "debug";
      };
      reload-triggers = [
        config.environment.etc."vector/vector.toml".source
      ];
    }
    // lib.optionalAttrs (cfg.dataDir == "/var/lib/vector") {
      state-dir = "vector";
      state-dir-mode = "0700";
    };

    users.users = lib.optionalAttrs (cfg.user == "vector") {
      vector = {
        inherit (cfg) group;

        isSystemUser = true;
      };
    };

    users.groups = lib.optionalAttrs (cfg.group == "vector") {
      vector = { };
    };
  };
}
