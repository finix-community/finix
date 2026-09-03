final: prev:
{
  appstream = prev.appstream.override { withSystemd = false; };
  at-spi2-core = prev.at-spi2-core.override { systemdSupport = false; }; # only needed for dbus-broker?
  bluez = prev.bluez.overrideAttrs (o: { configureFlags = o.configureFlags ++ [ (final.lib.enableFeature false "udev") ]; }); # TODO: upstream udevSupport and systemdSupport options
  cups = prev.cups.override { enableSystemd = false; };
  dbus = prev.dbus.override { enableSystemd = false; }; # complicated... we want dbus as a dependency to not depend on systemd... but as a service we do: systemdMinimal = final.systemdLibs;
  flatpak = prev.flatpak.override { withSystemd = false; };
  htop = prev.htop.override { systemdSupport = false; };
  libajantv2 = prev.libajantv2.override { udev = final.libudev-zero; };
  libcamera = prev.libcamera.override { udev = final.libudev-zero; };
  libcanberra = prev.libcanberra.override { withSystemd = false; };
  libfido2 = prev.libfido2.override { udev = final.libudev-zero; };
  libinput = prev.libinput.override { udev = final.libudev-zero; wacomSupport = false; };
  libusb1 = prev.libusb1.override { udev = final.libudev-zero; };
  linux-pam = prev.linux-pam.override { withLogind = false; }; # TODO: alternatively we could patch upstream nixpkgs expression to also support elogind...
  lvm2 = prev.lvm2.override { udevSupport = false; }; # not supported by libudev-zero
  modemmanager = prev.modemmanager.override { withSystemd = false; };
  networkmanager = prev.networkmanager.override { withSystemd = false; };
  openldap = prev.openldap.override { systemdMinimal = final.finit; }; # TODO: modify from systemdMinimal to systemdLibs on next nixpkgs bump
  ostree = prev.ostree.override { withSystemd = false; };
  packagekit = prev.packagekit.override { enableSystemd = false; };
  pcsclite = prev.pcsclite.override { systemdSupport = false; udev = final.libudev-zero; };
  ppp = prev.ppp.override { systemdMinimal = final.finit; };
  procps = prev.procps.override { withSystemd = false; };
  sdl3 = prev.sdl3.override { systemdLibs = final.libudev-zero; };
  smartmontools = prev.smartmontools.override { systemdLibs = final.finit; };
  util-linux = prev.util-linux.override { systemdSupport = false; };
  v4l-utils = prev.v4l-utils.override { udev = final.libudev-zero; };
  xdg-desktop-portal = prev.xdg-desktop-portal.override { enableSystemd = false; };
  xwayland-satellite = prev.xwayland-satellite.override { withSystemd = false; };

  /*
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
  */

  /*
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
  */
}
