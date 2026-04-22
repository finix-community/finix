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
