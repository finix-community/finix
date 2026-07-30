{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.yarr;
in {
  options.services.yarr = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [yarr](${pkgs.yarr.meta.homepage}) as a system service.
      '';
    };
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.yarr;
      description = ''
        The package to use for `yarr`.
      '';
    };

    address = lib.mkOption {
      type = lib.types.str;
      default = "localhost";
      description = "Address to run server on.";
    };

    stateDir = lib.mkOption {
      type = lib.types.path;

      default = "/var/lib/yarr";

      description = ''
        The directory used to store daemon state.

        It is recommended to leave this as is, otherwise you are responsible for ensuring the directory exists, etc.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 7070;
      description = "Port to run server on.";
    };

    baseUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Base path of the service url.";
    };

    authFilePath = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to a file containing username:password. `null` means no authentication required to use the service.";
    };

    extraFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Extra flags passed to `yarr`;
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [cfg.package];

    finit.services.yarr = {
      description = "yarr daemon service";
      conditions = "service/syslogd/ready";
      log = true;
      command = lib.strings.concatStringsSep " " (
        [
          "${lib.getExe cfg.package}"
          "-db"
          "${cfg.stateDir}/storage.db"
          "-addr"
          "${cfg.address}:${lib.toString cfg.port}"
        ]
        ++ lib.optional (cfg.baseUrl != null) "-base ${cfg.baseUrl}"
        ++ lib.optional (cfg.authFilePath != null) "-auth-file ${cfg.authFilePath}"
        ++ cfg.extraFlags
      );
    };

    finit.tmpfiles.rules = lib.optionals (cfg.stateDir == "/var/lib/yarr") [
      "d ${cfg.stateDir} 0700"
    ];
  };
}
