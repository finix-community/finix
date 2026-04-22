{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.plasma;

  inherit (pkgs) kdePackages;

  sessionFile = pkgs.writeTextDir "share/wayland-sessions/plasma.desktop" ''
    [Desktop Entry]
    Name=Plasma (Wayland)
    Comment=KDE Plasma Desktop
    Exec=${pkgs.dbus}/bin/dbus-run-session -- ${kdePackages.plasma-workspace}/bin/startplasma-wayland
    Type=Application
    DesktopNames=KDE
  '';
in
{
  options.programs.plasma = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable the KDE Plasma 6 Wayland session.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with kdePackages; [
      # session entry point
      (lib.hiPrio sessionFile)

      # Qt Wayland support
      qtwayland
      qtsvg

      # compositor
      kwin

      # core plasma
      plasma-workspace
      plasma-desktop
      kscreen
      libkscreen
      kactivitymanagerd
      kglobalacceld

      # KDE frameworks needed at runtime
      frameworkintegration
      kauth
      kcoreaddons
      kcmutils
      kded
      kfilemetadata
      kguiaddons
      kiconthemes
      kimageformats
      kio
      kpackage
      kservice
      solid
      plasma-activities # maybe?

      # QML / Qt plugins needed by plasmashell
      libplasma
      qqc2-desktop-style
      kde-cli-tools

      # theme
      breeze
      breeze-icons
      pkgs.hicolor-icon-theme
      qqc2-breeze-style

      # polkit agent
      polkit-kde-agent-1

      # platform integration
      plasma-integration

      drkonqi
    ];

    environment.pathsToLink = [
      "/share"

      # for drkonqi
      "/libexec"
    ];

    security.pam.environment =
      let
        qtVersions = with pkgs; [
          qt5
          qt6
        ];
      in
      {
        QT_PLUGIN_PATH.default = map (qt: "/run/current-system/sw/${qt.qtbase.qtPluginPrefix}") qtVersions;
        QML2_IMPORT_PATH.default = map (qt: "/run/current-system/sw/${qt.qtbase.qtQmlPrefix}") qtVersions;

        XDG_CONFIG_DIRS.default = [ "@{HOME}/.config/kdedefaults" ];
      };

    security.wrappers = {
      kwin_wayland = {
        owner = "root";
        group = "root";
        capabilities = "cap_sys_nice+ep";
        source = "${lib.getBin pkgs.kdePackages.kwin}/bin/kwin_wayland";
      };
    };

    xdg.portal.portals = [
      pkgs.kdePackages.xdg-desktop-portal-kde
      pkgs.xdg-desktop-portal-gtk
    ];
  };
}
