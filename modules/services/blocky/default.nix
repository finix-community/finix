{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.blocky;

  format = pkgs.formats.yaml { };
  configFile = format.generate "config.yaml" cfg.settings;
in
{
  options.services.blocky = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [blocky](${pkgs.blocky.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.blocky;
      defaultText = lib.literalExpression "pkgs.blocky";
      description = ''
        The package to use for `blocky`.
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
      default = "blocky";
      description = ''
        User account under which `blocky` runs.

        ::: {.note}
        If left as the default value this user will automatically be created
        on system activation, otherwise you are responsible for
        ensuring the user exists before the `blocky` service starts.
        :::
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "blocky";
      description = ''
        Group account under which `blocky` runs.

        ::: {.note}
        If left as the default value this group will automatically be created
        on system activation, otherwise you are responsible for
        ensuring the group exists before the `blocky` service starts.
        :::
      '';
    };

    settings = lib.mkOption {
      type = format.type;
      default = { };
      description = ''
        `blocky` configuration. See [upstream documentation](https://0xerr0r.github.io/blocky/configuration)
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # https://github.com/finit-project/finit/issues/454
    boot.kernel.sysctl."net.ipv4.ip_unprivileged_port_start" = 0;

    services.blocky.settings = {
      log = {
        level = lib.mkIf cfg.debug "debug";
        timestamp = false;
      };

      queryLog.type = lib.mkDefault "none";
    };

    finit.services.blocky = {
      inherit (cfg) user group;

      description = "a dns proxy and ad-blocker for the local network";
      conditions = [
        "service/syslogd/ready"
        "net/route/default"
      ];
      command = "${lib.getExe cfg.package} --config ${configFile}";
      log = true;
      nohup = true;

      # https://github.com/0xERR0R/blocky/issues/1910
      # TODO: now we're hijacking `env` and no one else can use it...
      environment = {
        NO_COLOR = 1;
      };
    };
  };
}
