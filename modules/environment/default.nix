{
  imports = [
    ./etc
    ./path
    ./shells
  ];

  config = {
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
      ANSI_COLOR="1;34"
      DEFAULT_HOSTNAME=finix
      DOCUMENTATION_URL="https://nixos.org/learn.html"
      HOME_URL="https://nixos.org/"
      ID=finix
      LOGO="nix-snowflake"
      NAME=finix
      PRETTY_NAME="finix 25.05"
      VERSION="25.05"
      VERSION_ID="25.05"
    '';
  };
}
