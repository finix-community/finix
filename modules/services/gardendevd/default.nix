{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.gardendevd;

  gardendevd = pkgs.callPackage ./package.nix {};
in
{
  options.services.gardendevd = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [gardendevd](${gardendevd.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = gardendevd;
      defaultText = lib.literalExpression "pkgs.gardendevd";
      description = ''
        The package to use for `gardendevd`.
      '';
    };

    # TODO: -K flag and maybe -d flag?
    # Or just extra flags section

    log-level = lib.mkOption {
      type = lib.types.enum [
        "debug"
        "info"
        "warning"
        "error"
      ];
      default = "info";
      example = "warning";
      description = ''
        Log level
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    services.mdevd.nlgroups = lib.mkForce 2;

    finit.services.gardendevd = {
      description = "udev daemon running on top of mdevd to replace systemd-udev";
      command = "${cfg.package}/bin/gardendevd -D %n -v " + lib.toString cfg.log-level;
      conditions = "service/mdevd/ready";
      notify = "s6";
      log = true;
    };
  };
}
