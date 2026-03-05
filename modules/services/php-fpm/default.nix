{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.php-fpm;

  format = pkgs.formats.iniWithGlobalSection { };
  configFile = format.generate "php-fpm.conf" {
    globalSection = lib.filterAttrs (_: v: !lib.isAttrs v) cfg.settings;
    sections = lib.filterAttrs (_: lib.isAttrs) cfg.settings;
  };

  poolOpts =
    { name, ... }:
    {
      freeformType =
        with lib.types;
        attrsOf (oneOf [
          str
          int
          bool
        ]);
      options = {
        listen = lib.mkOption {
          type =
            with lib.types;
            oneOf [
              path
              port
              str
            ];
          default = "/run/php-fpm/${name}.sock";
          defaultText = lib.literalExpression "/run/php-fpm/\${name}.sock";
          description = ''
            The address on which to accept FastCGI requests. Valid syntaxes are: `ip.add.re.ss:port`, `port`, `/path/to/unix/socket`.
          '';
        };

        pm = lib.mkOption {
          type = lib.types.enum [
            "static"
            "ondemand"
            "dynamic"
          ];
          description = ''
            Choose how the process manager will control the number of child processes.

            `static` - the number of child processes is fixed (`pm.max_children`).
            `ondemand` - the processes spawn on demand (when requested, as opposed to `dynamic`, where `pm.start_servers` are started when the service is started).
            `dynamic` - the number of child processes is set dynamically based on the following directives: `pm.max_children`, `pm.start_servers`, pm.min_spare_servers, `pm.max_spare_servers`.
          '';
        };

        "pm.max_children" = lib.mkOption {
          type = lib.types.int;
          description = ''
            The number of child processes to be created when `pm` is set to `static` and the maximum
            number of child processes to be created when `pm` is set to `dynamic`.

            This option sets the limit on the number of simultaneous requests that will be served.
          '';
        };

        user = lib.mkOption {
          type = lib.types.str;
          description = ''
            Unix user of FPM processes.
          '';
        };
      };
    };
in
{
  options.services.php-fpm = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [php-fpm](${pkgs.php.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.php;
      defaultText = lib.literalExpression "pkgs.php";
      description = ''
        The package to use for `php`.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType =
          with lib.types;
          attrsOf (oneOf [
            str
            int
            bool
            (submodule poolOpts)
          ]);
        options = {
          log_level = lib.mkOption {
            type = lib.types.enum [
              "alert"
              "error"
              "warning"
              "notice"
              "debug"
            ];
            default = "notice";
            description = ''
              Error log level.
            '';
          };
        };
      };
      default = { };
      description = ''
        `php-fpm` configuration. See [upstream documentation](https://www.php.net/manual/en/install.fpm.configuration.php)
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.php-fpm.settings = {
      error_log = "syslog";
      daemonize = false;
    };

    finit.services.php-fpm = {
      conditions = [ "service/syslogd/ready" ];
      command = "${cfg.package}/bin/php-fpm -y ${configFile}";
      reload = "${pkgs.coreutils}/bin/kill -USR2 $MAINPID";
      notify = "systemd";
    };

    finit.tmpfiles.rules = [
      "d /run/php-fpm"
    ];
  };
}
