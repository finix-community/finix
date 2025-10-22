{ config, pkgs, lib, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  # specify the keyboard
  hardware.console.keyMap = "us";

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
  programs.bash.enable = true;

  services.atd.enable = true;
  services.chrony.enable = true;
  services.cron.enable = true;
  services.dbus.enable = true;
  services.networkmanager.enable = true;
  services.nix-daemon.enable = true;
  services.openssh.enable = true;
  services.sysklogd.enable = true;
  services.logrotate.enable = true;
  services.udev.enable = true;

  # graphical desktop system profile
  programs.regreet.enable = true;

  services.bluetooth.enable = true;
  services.greetd.enable = true;
  services.seatd.enable = true;

  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true;
}
