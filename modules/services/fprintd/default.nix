{ config, pkgs, lib, ... }:
let
  cfg = config.services.fprintd;
in
{
  options.services.fprintd = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.fprintd;
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      { assertion = config.services.polkit.enable; message = "services.fprintd requires services.polkit.enable set to true"; }
    ];

    services.dbus.packages = [ cfg.package ];
    environment.systemPackages = [ cfg.package ];

    finit.services.fprintd = {
      description = "fingerprint authentication daemon";
      command = "${cfg.package}/libexec/fprintd --no-timeout";
      conditions = [ "service/dbus/ready" "service/polkit/ready" ];
      log = true;
      env = lib.mkIf cfg.debug (pkgs.writeText "fprintd.env" "G_MESSAGES_DEBUG=all");
    };
  };
}
