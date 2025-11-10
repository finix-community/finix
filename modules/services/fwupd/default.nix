{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.fwupd;

  format = pkgs.formats.ini {
    listToValue = l: lib.concatStringsSep ";" (map (s: lib.generators.mkValueStringDefault { } s) l);
    mkKeyValue = lib.generators.mkKeyValueDefault { } "=";
  };
in
{
  options.services.fwupd = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [fwupd](${pkgs.fwupd.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.fwupd;
      defaultText = lib.literalExpression "pkgs.fwupd";
      description = ''
        The package to use for `fwupd`.
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
      type = lib.types.submodule {
        freeformType = format.type;
        options = {
          fwupd = {
            IdleTimeout = lib.mkOption {
              type = lib.types.int;
              default = 0;
            };
          };
        };
      };
      default = { };
      description = ''
        `fwupd` configuration. See {manpage}`fwupd.conf(5)`
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc =
      let
        vendor = lib.genAttrs cfg.package.filesInstalledToEtc (file: {
          source = "${cfg.package}/etc/${file}";
        });

        local = {
          "fwupd/fwupd.conf" = {
            source = format.generate "fwupd.conf" cfg.settings;
            mode = "0640";
          };
        };
      in
      vendor // local;

    environment.systemPackages = [
      cfg.package
    ];

    services.dbus.packages = [ cfg.package ];
    services.udev.packages = [ cfg.package ];

    finit.services.fwupd = {
      description = "";
      command =
        "${cfg.package}/libexec/fwupd/fwupd --no-timestamp" + lib.optionalString cfg.debug " --verbose";
      conditions = [
        "service/dbus/ready"
        "service/polkit/ready"
      ];
      log = true;
      nohup = true;

      # TODO: now we're hijacking `env` and no one else can use it...
      env = pkgs.writeText "fwupd.env" ''
        NO_COLOR=1
      '';
    };

    services.tmpfiles.fwupd.rules = [
      "/var/lib/fwupd"
      "/var/cache/fwupd"
    ];
  };
}
