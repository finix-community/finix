{ config, pkgs, lib, ... }:
let
  cfg = config.services.elogind;
in
{
  options.services.elogind = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    package = lib.mkOption {
      type = lib.types.package;
      # default = pkgs.elogind;
      default = pkgs.elogind.overrideAttrs (old: {
        mesonFlags = old.mesonFlags ++ [
          (lib.mesonBool "log-trace" true)
          (lib.mesonOption "debug-extra" "elogind")
        ];
      });
    };
  };

  options.finit.ttys = lib.mkOption {
    type = with lib.types; attrsOf (submodule {
      config = lib.mkIf cfg.enable {
        conditions = "service/elogind/ready";
      };
    });
  };

  config = lib.mkIf cfg.enable {
    finit.services.elogind = {
      description = "login manager";
      conditions = [ "service/syslogd/ready" "service/dbus/ready" ];
      command = "${cfg.package}/libexec/elogind";
    };

    environment.systemPackages = [ cfg.package ];

    environment.etc."elogind/logind.conf".text = ''
      [Login]
    '';

    environment.etc."elogind/sleep.conf".text = ''
      [Sleep]
    '';
  };
}
