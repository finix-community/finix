{
  modules,
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.lxqt;

  inherit (pkgs) lxqt;
  inherit (pkgs) kdePackages;

  xSessionFile = pkgs.writeTextDir "share/xsessions/lxqt.desktop" ''
    [Desktop Entry]
    Name=LXQt (X11)
    Comment=LXQt Desktop
    Exec=${pkgs.lxqt.lxqt-session}/bin/startlxqt
    Type=Application
    DesktopNames=LXQt
  '';

  waylandSessionFile = pkgs.writeTextDir "share/wayland-sessions/lxqt-wayland.desktop" ''
    [Desktop Entry]
    Name=LXQt (Wayland)
    Comment=LXQt Wayland Desktop
    Exec=${pkgs.dbus}/bin/dbus-run-session -- ${pkgs.lxqt.lxqt-wayland-session}/bin/startlxqtwayland
    Type=Application
    DesktopNames=LXQt
  '';

  libinput = pkgs.libinput.override (
    lib.optionalAttrs (config.services.mdevd.enable || config.services.keventd.enable) {
      udev = pkgs.libudev-zero;
      wacomSupport = false;
    }
  );

  # TODO: present in nixpkgs utils module, maybe port to finix?
  removePackagesByName =
    packages: packagesToRemove:
    let
      namesToRemove = map lib.getName packagesToRemove;
    in
    lib.filter (x: !(lib.elem (lib.getName x) namesToRemove)) packages;

  packages = {
    preRequisitePackages = [
      kdePackages.kwindowsystem # provides some QT plugins needed by lxqt-panel
      kdePackages.libkscreen # provides plugins for screen management software
      pkgs.libfm
      pkgs.libfm-extra
      pkgs.menu-cache
      kdePackages.qtsvg # provides QT plugins for svg icons
    ];

    corePackages = [
      ### BASE
      lxqt.libqtxdg
      lxqt.libsysstat
      lxqt.liblxqt
      lxqt.qtxdg-tools
      lxqt.libdbusmenu-lxqt

      ### CORE 1
      lxqt.libfm-qt
      lxqt.lxqt-about
      lxqt.lxqt-admin
      lxqt.lxqt-config
      lxqt.lxqt-menu-data
      lxqt.lxqt-notificationd
      lxqt.lxqt-openssh-askpass
      lxqt.lxqt-powermanagement
      lxqt.lxqt-qtplugin
      lxqt.lxqt-sudo
      lxqt.lxqt-themes
      lxqt.pavucontrol-qt
      lxqt.lxqt-session
      lxqt.lxqt-wayland-session

      ### CORE 2
      lxqt.lxqt-panel
      lxqt.lxqt-runner
      lxqt.pcmanfm-qt

      pkgs.xdg-utils
      pkgs.libnotify
    ]
    ++ lib.optionals config.services.elogind.enable [
      ### CORE 1
      lxqt.lxqt-policykit
    ]
    ++ lib.optionals cfg.xsession.enable [
      ### CORE 1
      pkgs.lxqt.lxqt-globalkeys
    ];

    optionalPackages = [
      ### LXQt project
      lxqt.qterminal
      lxqt.obconf-qt
      lxqt.lximage-qt
      lxqt.lxqt-archiver

      ### QtDesktop project
      lxqt.qps
      lxqt.screengrab

      ### Screen saver
      pkgs.xscreensaver
    ];
  };

in
{
  imports = [ modules.labwc ];

  options.programs.lxqt = {

    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [LXQt](https://lxqt-project.org/).
      '';
    };

    iconTheme = lib.mkPackageOption pkgs [ "kdePackages" "breeze-icons" ] { } // {
      description = "The package that provides a default icon theme.";
    };

    extraPackages = lib.mkOption {
      type = with lib.types; listOf package;
      default = [ ];
      description = ''
        Extra packages to be installed system wide.
      '';
    };

    excludePackages = lib.mkOption {
      type = with lib.types; listOf package;
      default = [ ];
      description = ''
        Which LXQt packages to exclude from the default environment.
      '';
    };

    wayland = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Whether to enable the LXQt desktop environment's Wayland session.
        '';
      };

      compositor = lib.mkOption {
        type = lib.types.package;
        default = config.programs.labwc.package;
        defaultText = lib.literalExpression "config.programs.labwc.package";
        description = ''
          The default Wayland compositor package to use.
        '';
      };
    };

    xsession = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable the LXQt desktop environment's X11 session.
        '';
      };

      windowManager = lib.mkOption {
        type = lib.types.package;
        default = pkgs.openbox;
        defaultText = lib.literalExpression "pkgs.openbox";
        description = ''
          The default X11 window manager package to use.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.xsession.enable -> config.services.xserver.enable or false;
        message = "`config.services.xserver.enable` must be set to `true` in order to use the LXQt xorg session.";
      }
    ];

    environment.systemPackages =
      packages.preRequisitePackages
      ++ packages.corePackages
      ++ packages.optionalPackages
      ++ [ cfg.iconTheme ]
      ++ (removePackagesByName packages.optionalPackages cfg.excludePackages)
      ++ cfg.extraPackages
      ++ lib.optionals cfg.wayland.enable [
        (lib.hiPrio waylandSessionFile)
        cfg.wayland.compositor
      ]
      ++ lib.optionals cfg.xsession.enable [
        (lib.hiPrio xSessionFile)
        cfg.xsession.windowManager

        # had issues without this package
        pkgs.libxcb-cursor
      ];

    environment.pathsToLink = [
      "/share"
      "/share/icons"
      "/share/pixmaps"
    ];

    security.pam.environment = {
      XDG_CONFIG_DIRS.default = [ "/run/current-system/sw/share" ];
    };

    xdg.portal.portals = [
      pkgs.lxqt.xdg-desktop-portal-lxqt
    ];

    environment.etc."xdg/lxqt/session.conf".source = (pkgs.formats.ini { }).generate "session.conf" {
      General =
        lib.optionalAttrs cfg.wayland.enable { compositor = cfg.wayland.compositor.pname; }
        // lib.optionalAttrs cfg.xsession.enable { window_manager = cfg.xsession.windowManager.pname; };
    };
  };
}
