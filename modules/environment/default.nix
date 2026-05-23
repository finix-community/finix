{ pkgs, ... }:
let
  finix-logo = pkgs.runCommand "finix-logo" { } ''
    install -Dm644 ${../../assets/finix-logo.svg} $out/share/icons/hicolor/scalable/apps/finix-logo.svg
  '';
in
{
  imports = [
    ./etc
    ./path
    ./shells
  ];

  config = {
    environment.systemPackages = [ finix-logo ];
    environment.etc."nsswitch.conf".text = ''
      # /etc/nsswitch.conf
      #
      # Example configuration of GNU Name Service Switch functionality.
      # If you have the `glibc-doc-reference' and `info' packages installed, try:
      # `info libc "Name Service Switch"' for information about this file.

      passwd:         files
      group:          files
      shadow:         files
      gshadow:        files

      hosts:          files dns
      networks:       files

      protocols:      db files
      services:       db files
      ethers:         db files
      rpc:            db files

      netgroup:       nis
    '';

    environment.etc.os-release.text = ''
      ANSI_COLOR="0;38;2;231;56;71"
      BUG_REPORT_URL="https://github.com/finix-community/finix/issues/"
      DEFAULT_HOSTNAME=finix
      HOME_URL="https://github.com/finix-community/finix/"
      ID=finix
      LOGO=finix-logo
      NAME=finix
      PRETTY_NAME="finix 25.05"
      VENDOR_NAME=finix
      VENDOR_URL="https://github.com/finix-community/finix/"
      VERSION="25.05"
      VERSION_ID="25.05"
    '';
  };
}
