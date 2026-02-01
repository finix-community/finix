# common test configuration
#
# provides shared configuration for all finix tests
{ pkgs, ... }:
{
  finit.runlevel = 2;
  services.mdevd.enable = true;

  # use finit 4.16 from upstream until nixpkgs is updated
  finit.package = pkgs.finit.overrideAttrs (finalAttrs: {
    version = "4.16alpha";
    src = pkgs.fetchFromGitHub {
      owner = "finit-project";
      repo = "finit";
      rev = "dacda5ab5d449cf5451e83d4c770758d0e32f901";
      hash = "sha256-thC3aG5o3dFbUWW32IagqUmlkamhgyYwbe8Ue0EhyV4=";
    };
  });
}
