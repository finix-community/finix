final: prev:
{
  appstream = prev.appstream.override { withSystemd = false; };
  at-spi2-core = prev.at-spi2-core.override { systemdSupport = false; }; # only needed for dbus-broker?
  bluez = prev.bluez.overrideAttrs (o: { configureFlags = o.configureFlags ++ [ (final.lib.enableFeature false "udev") (final.lib.enableFeature false "systemd") ]; }); # TODO: upstream udevSupport and systemdSupport options
  colord = prev.colord.overrideAttrs { enableSystemd = false; udev = final.libudev-zero; }; # TODO: systemd -> systemdLibs
  cups = prev.cups.override { enableSystemd = false; };
  dbus = prev.dbus.override { enableSystemd = false; }; # complicated... we want dbus as a dependency to not depend on systemd... but as a service we do: systemdMinimal = final.systemdLibs;
  flatpak = prev.flatpak.override { withSystemd = false; };
  fwupd = prev.fwupd.overrideAttrs (o: { mesonFlags = o.mesonFlags ++ [ (final.lib.mesonEnable "logind" false) (final.lib.mesonEnable "systemd" false) ]; }); # TODO: make upstream systemdSupport option
  gnome-settings-daemon = prev.gnome-settings-daemon.override { withSystemd = false; };
  gnome-settings-daemon48 = prev.gnome-settings-daemon48.override { withSystemd = false; };
  gvfs = prev.gvfs.overrideAttrs (o: { mesonFlags = o.mesonFlags ++ [ "-Dlogind=false" ]; });
  htop = prev.htop.override { systemdSupport = false; };
  hyprland = prev.hyprland.override { withSystemd = false; };
  libajantv2 = prev.libajantv2.override { udev = final.libudev-zero; };
  libcamera = prev.libcamera.override { udev = final.libudev-zero; };
  libcanberra = prev.libcanberra.override { withSystemd = false; };
  libei = prev.libei.override { systemdLibs = final.basu; };
  libfido2 = prev.libfido2.override { udev = final.libudev-zero; };
  # libfprint = prev.libfprint.override { };
  libgudev = prev.libgudev.override { udev = final.libudev-zero; withIntrospection = false; };
  libinput = prev.libinput.override { udev = final.libudev-zero; wacomSupport = false; };
  libmanette = prev.libmanette.overrideAttrs (o: { mesonFlags = o.mesonFlags ++ [ (final.lib.mesonEnable "gudev" false) ]; }); # TODO: add udevSupport to upstream
  libqmidev = prev.libqmidev.override { withIntrospection = false; };
  libusb1 = prev.libusb1.override { udev = final.libudev-zero; };
  linux-pam = prev.linux-pam.override { withLogind = false; }; # TODO: alternatively we could patch upstream nixpkgs expression to also support elogind...
  lvm2 = prev.lvm2.override { udevSupport = false; }; # not supported by libudev-zero
  modemmanager = prev.modemmanager.override { withSystemd = false; };
  networkmanager = prev.networkmanager.override { withSystemd = false; };
  openldap = prev.openldap.override { systemdMinimal = final.finit; }; # TODO: modify from systemdMinimal to systemdLibs on next nixpkgs bump
  ostree = prev.ostree.override { withSystemd = false; };
  packagekit = prev.packagekit.override { enableSystemd = false; };
  pcsclite = prev.pcsclite.override { systemdSupport = false; udev = final.libudev-zero; };
  pipewire = (prev.pipewire.overrideAttrs (o: { mesonFlags = o.mesonFlags ++ [ (final.lib.mesonEnable "logind" false) ]; })).override { enableSystemd = false; udev = final.libudev-zero; };
  polkit = prev.polkit.override { useConsoleKit = true; useSystemd = false; };
  ppp = prev.ppp.override { systemdMinimal = final.finit; };
  procps = prev.procps.override { withSystemd = false; };
  rdma-core = prev.rdma-core.override { udev = final.libudev-zero; };
  sdl3 = prev.sdl3.override { systemdLibs = final.libudev-zero; };
  seatd = prev.seatd.override { systemdSupport = false; };
  smartmontools = prev.smartmontools.overrideAttrs (o: { buildInputs = [ ]; }); # TODO: update finit or something? prev.smartmontools.override { systemdLibs = final.finit; };
  upower = prev.upower.override { withIntrospection = false; withSystemd = false; udev = final.libudev-zero; };
  util-linux = prev.util-linux.override { systemdSupport = false; };
  v4l-utils = prev.v4l-utils.override { udev = final.libudev-zero; };
  wireplumber = prev.wireplumber.overrideAttrs (o: { mesonFlags = o.mesonFlags ++ [ (final.lib.mesonEnable "systemd" false) ]; });
  xdg-desktop-portal = prev.xdg-desktop-portal.override { enableSystemd = false; };
  xwayland-satellite = prev.xwayland-satellite.override { withSystemd = false; };

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
}
