{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.power-profiles-daemon;
in
{
  options.services.power-profiles-daemon = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [power-profiles-daemon](${pkgs.power-profiles-daemon.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.power-profiles-daemon;
      defaultText = lib.literalExpression "pkgs.power-profiles-daemon";
      description = ''
        The package to use for `power-profiles-daemon`.
      '';
    };

    extraGroups = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      example = lib.literalExpression "[ config.services.seatd.group ]";
      description = ''
        A list of groups to _unconditionally_ grant access, via `polkit`, to this services offerings. Useful
        on systems without `(e)logind`. See [Using polkit with seatd](https://wiki.alpinelinux.org/wiki/Polkit#Using_polkit_with_seatd)
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {

    environment.systemPackages = [ cfg.package ];

    services.dbus.packages = [ cfg.package ];
    services.udev.packages = [ cfg.package ];
    services.polkit.extraConfig = lib.optionalString (cfg.extraGroups != [ ]) ''
      polkit.addRule(function(action, subject) {
        if (action.id.startsWith("org.freedesktop.UPower.PowerProfiles.")) {
          var groups = ${builtins.toJSON cfg.extraGroups};

          if (groups.some(function(group) {
            return subject.isInGroup(group);
          })) {
            return polkit.Result.YES;
          }
        }

        return polkit.Result.NOT_HANDLED;
      });
    '';

    finit.services.power-profiles-daemon = {
      description = "power profiles daemon";
      conditions = "service/dbus/ready";
      command = "${cfg.package}/libexec/power-profiles-daemon";
    };

    finit.tmpfiles.rules = [
      "d /var/lib/power-profiles-daemon"
    ];
  };
}
