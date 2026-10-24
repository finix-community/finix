final: prev: {
  appstream = prev.appstream.override { withSystemd = false; };

  at-spi2-core = prev.at-spi2-core.override { systemdSupport = false; };

  colord = prev.colord.overrideAttrs {
    enableSystemd = false;
    udev = final.libudev-zero;
  };

  cosmic-comp = prev.cosmic-comp.override { useSystemd = false; };

  cosmic-greeter = prev.cosmic-greeter.override { withSystemd = false; };

  cosmic-session = prev.cosmic-session.override { withSystemd = false; };

  cups = prev.cups.override { enableSystemd = false; };

  # complicated... we want dbus as a dependency to not depend on systemd... but as a service we do: systemdMinimal = final.systemdLibs;
  dbus = prev.dbus.override { enableSystemd = false; };

  flatpak = prev.flatpak.override { withSystemd = false; };

  gnome-settings-daemon48 = prev.gnome-settings-daemon48.override { withSystemd = false; };

  gnome-settings-daemon = prev.gnome-settings-daemon.override { withSystemd = false; };

  htop = prev.htop.override { systemdSupport = false; };

  hyprland = prev.hyprland.override { withSystemd = false; };

  libajantv2 = prev.libajantv2.override { udev = final.libudev-zero; };

  libcamera = prev.libcamera.override { udev = final.libudev-zero; };

  libcanberra = prev.libcanberra.override { withSystemd = false; };

  libei = prev.libei.override { systemdLibs = final.basu; };

  libfido2 = prev.libfido2.override { udev = final.libudev-zero; };

  libgudev = prev.libgudev.override {
    udev = final.libudev-zero;
    withIntrospection = false;
  };

  libinput = prev.libinput.override {
    udev = final.libudev-zero;
    wacomSupport = false;
  };

  libqmidev = prev.libqmidev.override { withIntrospection = false; };

  libusb1 = prev.libusb1.override { udev = final.libudev-zero; };

  linux-pam = prev.linux-pam.override { withLogind = false; };

  lvm2 = prev.lvm2.override { udevSupport = false; };

  modemmanager = prev.modemmanager.override { withSystemd = false; };

  networkmanager = prev.networkmanager.override { withSystemd = false; };

  niri = prev.niri.override { withSystemd = false; };

  # TODO: consider switching to `withSystemd = false`
  openldap = prev.openldap.override { systemdMinimal = final.finit; };

  ostree = prev.ostree.override { withSystemd = false; };

  packagekit = prev.packagekit.override { enableSystemd = false; };

  pcsclite = prev.pcsclite.override {
    systemdSupport = false;
    udev = final.libudev-zero;
  };

  polkit = prev.polkit.override {
    useConsoleKit = true;
    useSystemd = false;
  };

  ppp = prev.ppp.override { withSystemd = false; };

  procps = prev.procps.override { withSystemd = false; };

  qt5 =
    let
      modify =
        scope:
        (scope.overrideScope (
          qfinal: qprev: {
            qtbase = qprev.qtbase.override {
              udev = final.libudev-zero;
            };
          }
        ))
        // {
          override = args: modify (scope.override args);
        };
    in
    modify prev.qt5;

  qt6 =
    let
      modify =
        scope:
        (scope.overrideScope (
          qfinal: qprev: {
            qtbase = qprev.qtbase.override {
              systemdSupport = false;
              udev = final.libudev-zero;
            };

            qtserialport = (qprev.qtserialport.override { udev = null; }).overrideAttrs (old: {
              cmakeFlags = (old.cmakeFlags or [ ]) ++ [ "-DQT_FEATURE_libudev=OFF" ]; # TODO: could add a udevSupport option, its basically already the
            });
          }
        ))
        // {
          override = args: modify (scope.override args);
        };
    in
    modify prev.qt6;

  rdma-core = prev.rdma-core.override { udev = final.libudev-zero; };

  sdl3 = prev.sdl3.override { systemdLibs = final.libudev-zero; };

  seatd = prev.seatd.override { systemdSupport = false; };

  sway-unwrapped = prev.sway-unwrapped.override { systemdSupport = false; };

  upower = prev.upower.override {
    withIntrospection = false;
    udev = final.libudev-zero;
  };

  util-linux = prev.util-linux.override { systemdSupport = false; };

  v4l-utils = prev.v4l-utils.override { udev = final.libudev-zero; };

  xwayland-satellite = prev.xwayland-satellite.override { withSystemd = false; };

  # TODO: requires some upstream work

  bluez = prev.bluez.overrideAttrs (o: {
    configureFlags = o.configureFlags ++ [
      (final.lib.enableFeature false "udev")
      (final.lib.enableFeature false "systemd")
    ];
  });

  fwupd = prev.fwupd.overrideAttrs (o: {
    mesonFlags = o.mesonFlags ++ [
      (final.lib.mesonEnable "logind" false)
      (final.lib.mesonEnable "systemd" false)
    ];
  });

  gvfs = prev.gvfs.overrideAttrs (o: {
    mesonFlags = o.mesonFlags ++ [ "-Dlogind=false" ];
  });

  libmanette = prev.libmanette.overrideAttrs (o: {
    mesonFlags = o.mesonFlags ++ [ (final.lib.mesonEnable "gudev" false) ];
  });

  pipewire =
    (prev.pipewire.overrideAttrs (o: {
      mesonFlags = o.mesonFlags ++ [ (final.lib.mesonEnable "logind" false) ];
    })).override
      {
        enableSystemd = false;
        udev = final.libudev-zero;
      };

  smartmontools = prev.smartmontools.overrideAttrs (o: {
    buildInputs = [ ];
  });

  wireplumber = prev.wireplumber.overrideAttrs (o: {
    mesonFlags = o.mesonFlags ++ [ (final.lib.mesonEnable "systemd" false) ];
  });

  xdg-desktop-portal =
    (prev.xdg-desktop-portal.override { enableSystemd = false; }).overrideAttrs
      (o: {
        postPatch = o.postPatch + ''
          sed -i "/'test_usb.py',/d" tests/meson.build
        '';
      });

  tmux = prev.tmux.override { withSystemd = false; };
}
