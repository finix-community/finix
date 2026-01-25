{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
  ];

  finit.package = pkgs.finit.overrideAttrs (_: {
    version = "4.16alpha";
    src = pkgs.fetchFromGitHub {
      owner = "finit-project";
      repo = "finit";
      rev = "dacda5ab5d449cf5451e83d4c770758d0e32f901";
      hash = "sha256-thC3aG5o3dFbUWW32IagqUmlkamhgyYwbe8Ue0EhyV4=";
    };
  });

  # set your time zone
  time.timeZone = "America/Toronto";

  # define a user account - don't forget to generate set a hashed password
  users.users.root.password = "$y$j9T$aMnujgTGz5qBbKMLbqhZ/.$VWuJHajf7p26mD/mLDboEtnqWJdkjYC5OEYeaXD8eq7";

  # list packgaes installed in system profile
  environment.systemPackages = with pkgs; [
    iproute2
    iputils
    nettools
    nixos-rebuild-ng
  ];

  # base system profile
  programs.bash.enable = true;

  programs.ifupdown-ng.enable = true;
  services.nix-daemon.enable = true;
  services.sysklogd.enable = true;
  services.mdevd.enable = true;
}
