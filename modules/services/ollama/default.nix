{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.ollama;

  format = pkgs.formats.keyValue { };
in
{
  options.services.ollama = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [ollama](${pkgs.ollama.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.ollama;
      defaultText = lib.literalExpression "pkgs.ollama";
      example = lib.literalExpression "pkgs.ollama-vulkan";
      description = ''
        The package to use for `ollama`.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "ollama";
      description = ''
        User account under which `ollama` runs.

        ::: {.note}
        If left as the default value this user will automatically be created
        on system activation, otherwise you are responsible for
        ensuring the user exists before the `ollama` service starts.
        :::
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "ollama";
      description = ''
        Group account under which `ollama` runs.

        ::: {.note}
        If left as the default value this group will automatically be created
        on system activation, otherwise you are responsible for
        ensuring the group exists before the `ollama` service starts.
        :::
      '';
    };

    stateDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/ollama";
      description = ''
        The directory used to store all `ollama` data.

        ::: {.note}
        If left as the default value this directory will automatically be created on
        service activation, otherwise you are responsible for ensuring the directory exists
        with appropriate ownership and permissions before the `ollama` service starts.
        :::
      '';
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = format.type;

        options = {
          OLLAMA_HOST = lib.mkOption {
            type = lib.types.str;
            default = "127.0.0.1:11434";
            description = ''
              The address and port to listen on.
            '';
          };

          OLLAMA_MODELS = lib.mkOption {
            type = lib.types.str;
            default = "${cfg.stateDir}/models";
            defaultText = lib.literalExpression ''"''${config.services.ollama.stateDir}/models"'';
            description = ''
              The directory to store models in.
            '';
          };
        };
      };
      default = { };
      description = ''
        `ollama` configuration. See [upstream documentation](https://docs.ollama.com/faq)
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.ollama.settings = lib.optionalAttrs cfg.debug {
      OLLAMA_DEBUG = 1;
    };

    environment.systemPackages = [ cfg.package ];

    finit.services.ollama = {
      inherit (cfg) user group;

      description = "server for local large language models";
      conditions = "service/syslogd/ready";
      command = "${lib.getExe cfg.package} serve";
      log = { };
      reload-signal = "none";
      extra-groups = [
        "video"
        "render"
      ];

      environment = cfg.settings // {
        HOME = cfg.stateDir;
      };
    }
    // lib.optionalAttrs (cfg.stateDir == "/var/lib/ollama") {
      state-dir = "ollama";
      state-dir-mode = "0750";
    };

    users.users = lib.optionalAttrs (cfg.user == "ollama") {
      ollama = {
        inherit (cfg) group;

        isSystemUser = true;
        home = cfg.stateDir;
      };
    };

    users.groups = lib.optionalAttrs (cfg.group == "ollama") {
      ollama = { };
    };
  };
}
