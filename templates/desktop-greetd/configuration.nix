{ config, pkgs, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  # set your time zone
  time.timeZone = "America/Toronto";

  # define a user account - don't forget to generate set a hashed password
  # users.users.alice = {
  #   isNormalUser = true;
  #   password = "...";
  #   shell = pkgs.fish;
  #   home = "/home/aaron";
  #   createHome =  true;
  #   group = "users";
  #   extraGroups = [ "wheel" "seat" "networkmanager" ]; # Enable ‘sudo’ for the user.
  # };

  # list packgaes installed in system profile
  environment.systemPackages = with pkgs; [
    iproute2 iputils nettools
    grub2_efi efibootmgr
    acpi pmutils

    mako walker waybar
    niri swaybg

    firefox ghostty imv
  ];

  # graphical runlevel
  finit.runlevel = 3;

  # base system profile
  services.atd.enable = true;
  services.chrony.enable = true;
  services.vixie-cron.enable = true;
  services.dbus.enable = true;
  services.dbus.package = pkgs.dbus.override { enableSystemd = false; };
  services.networkmanager.enable = true;
  services.nix-daemon.enable = true;
  services.openssh.enable = true;
  services.syslog.enable = true;
  services.logrotate.enable = true;
  services.udev.enable = true;

  # graphical desktop system profile
  services.bluetooth.enable = true;
  services.greetd.enable = true; # TODO: find a login manager that supports reload on SIGHUP + running without logind :'-(
  services.seatd.enable = true;

  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
}
