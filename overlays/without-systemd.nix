final: prev: {
  __toString = _: "${prev.__toString or (_: "nixpkgs") prev}:without-systemd";
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
}
