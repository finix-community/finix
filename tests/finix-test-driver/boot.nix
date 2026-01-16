# test that the system boots successfully
#
# a minimal test that just verifies the vm boots to runlevel 2
# useful for isolating boot issues from test driver issues
{
  name = "finix-test-driver.boot";

  nodes.machine =
    { pkgs, ... }:
    {
      finit.runlevel = 2;
      services.mdevd.enable = true;

      finit.package = pkgs.finit.overrideAttrs (finalAttrs: {
        version = "4.15";

        src = pkgs.fetchFromGitHub {
          owner = "aanderse";
          repo = "finit";
          rev = "29029bb78f513876665a64072e066db9a18d2241";
          sha256 = "sha256-X9ORF/OkSD2nrMzPXT9p3+GYI0Fa/5KDRl5p42Z7maA=";
        };
      });
    };

  testScript = ''
    machine start
    machine expect -timeout 30 "entering runlevel 2"

    log "system booted to runlevel 2 successfully"

    success
  '';
}
