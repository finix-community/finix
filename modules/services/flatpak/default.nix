{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.flatpak;
in
{
  options.services.flatpak = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [flatpak](${pkgs.flatpak.meta.homepage}).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.flatpak.override { withSystemd = false; };
      defaultText = lib.literalExpression "pkgs.flatpak.override { withSystemd = false; }";
      description = ''
        The package to use for `flatpak`.
      '';
    };

    extraGroups = lib.mkOption {
      type = with lib.types; listOf str;
      default = null;
      example = lib.literalExpression "[ config.services.seatd.group ]";
      description = ''
        A list of groups to _unconditionally_ grant access, via `polkit`, to this services offerings. Useful
        on systems without `(e)logind`. See [Using polkit with seatd](https://wiki.alpinelinux.org/wiki/Polkit#Using_polkit_with_seatd)
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.polkit.enable;
        message = "services.flatpak requires services.polkit.enable set to true";
      }
    ];

    environment.systemPackages = [
      cfg.package
      pkgs.fuse3
    ];

    services.dbus.packages = [ cfg.package ];
    services.polkit.extraConfig = lib.optionalString (cfg.extraGroups != [ ]) ''
      polkit.addRule(function(action, subject) {
        if (action.id.startsWith("org.freedesktop.Flatpak.")) {
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

    security.pam.environment = {
      PATH.default = lib.mkBefore [
        "@{HOME}/.local/share/flatpak/exports/bin"
        "/var/lib/flatpak/exports/bin"
      ];
      XDG_DATA_DIRS.default = [
        "@{HOME}/.local/share/flatpak/exports/share"
        "/var/lib/flatpak/exports/share"
      ];
    };

    users.users.flatpak = {
      description = "Flatpak system helper";
      group = "flatpak";
      isSystemUser = true;
    };

    users.groups.flatpak = { };
  };
}
