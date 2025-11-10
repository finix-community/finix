{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.elogind;
in
{
  options.services.elogind = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [elogind](${pkgs.elogind.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.elogind.overrideAttrs (old: {
        postPatch = old.postPatch + ''
          # TODO: upstream
          substituteInPlace ./rules.d/71-seat.rules.in \
            --replace-fail "{{BINDIR}}/udevadm" "${pkgs.eudev}/bin/udevadm"
        '';
      });
      defaultText = lib.literalExpression "pkgs.elogind";
      description = ''
        The package to use for `elogind`.
      '';
    };
  };

  options.finit.ttys = lib.mkOption {
    type =
      with lib.types;
      attrsOf (submodule {
        config = lib.mkIf cfg.enable {
          conditions = "service/elogind/ready";
        };
      });
  };

  config = lib.mkIf cfg.enable {
    finit.services.elogind = {
      description = "login manager";
      conditions = [
        "service/syslogd/ready"
        "service/dbus/ready"
      ];
      command = "${cfg.package}/libexec/elogind";
    };

    services.dbus.packages = [ cfg.package ];
    services.udev.packages = [ cfg.package ];

    environment.systemPackages = [ cfg.package ];

    environment.etc."elogind/logind.conf".text = ''
      [Login]
    '';

    environment.etc."elogind/sleep.conf".text = ''
      [Sleep]
    '';
  };
}
