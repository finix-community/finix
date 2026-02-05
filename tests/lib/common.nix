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
      owner = "aanderse";
      repo = "finit";
      rev = "31ba2178b7ce3b91b65af5015f293257fdfc50f6";
      hash = "sha256-Yjne6EbnM9QgsarNygcGSzQTfkYOm3yl+o8lhY8nv2Y=";
    };
  });
}
