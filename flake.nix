{
  description = "A collection of overlays and modules for finix";

  outputs = { self }: {
    nixosModules = import ./modules;

    overlays = {
      default = final: prev: {
        # TODO: upstream in nixpkgs
        finit = prev.callPackage ./pkgs/finit { };

        # see https://github.com/eudev-project/eudev/pull/290
        eudev = prev.eudev.overrideAttrs (o: {
          patches = (o.patches or [ ]) ++ [
            (final.fetchpatch {
              name = "s6-readiness.patch";
              url = "https://github.com/eudev-project/eudev/pull/290/commits/48e9923a1d0218d714989d8aec119e301aa930ae.patch";
              sha256 = "sha256-Icor2v2OYizquLW0ytYONjhCUW+oTs5srABamQR9Uvk=";
            })
          ];
        });

        # fork of sysklogd - same author as finit
        # currently experiencing bug with this, need to look into it
        sysklogd = prev.callPackage ./pkgs/sysklogd { };

        # relevant software for systems without logind - want to take a look at
        pam_xdg = prev.callPackage ./pkgs/pam_xdg { };
      };

      # work in progress overlay to build software without systemd, not currently usable
      without-systemd = final: prev: {
        dbus = prev.dbus.override { enableSystemd = false; };
        htop = prev.htop.override { systemdSupport = false; };
        hyprland = prev.hyprland.override { withSystemd = false; };
        modemmanager = prev.modemmanager.override { withSystemd = false; };
        networkmanager = prev.networkmanager.override { withSystemd = false; };
        niri = prev.niri.override { withSystemd = false; };
        pipewire = prev.pipewire.override { enableSystemd = false; };
        polkit = prev.polkit.override { useSystemd = false; };
        procps = prev.procps.override { withSystemd = false; };
        pulseaudio = prev.pulseaudio.override { useSystemd = false; };
        seatd = prev.seatd.override { systemdSupport = false; };
        sway-unwrapped = prev.sway-unwrapped.override { systemdSupport = false; };
        swayidle = prev.swayidle.override { systemdSupport = false; };
        upower = prev.upower.override { withSystemd = false; };
        util-linux = prev.util-linux.override { systemdSupport = false; };
        waybar = prev.waybar.override { systemdSupport = false; };
        xdg-desktop-portal = prev.xdg-desktop-portal.override { enableSystemd = false; };
        xwayland-satellite = prev.xwayland-satellite.override { withSystemd = false; };
      };
    };

    templates = {
      default = self.templates.desktop-greetd;

      desktop-greetd = {
        path = ./templates/desktop-greetd;
        description = "A simple desktop running the niri scrollable-tiling wayland compositor";
      };

      # TODO: desktop-logind
    };
  };
}
