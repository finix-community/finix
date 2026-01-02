{
  testenv ? import ./testenv { },
}:

testenv.mkTest {
  name = "finit";

  nodes.machine =
    { pkgs, ... }:
    {
      boot.serviceManager = "finit";

      finit.runlevel = 2;
      services.mdevd.enable = true;

      finit.package = pkgs.finit.overrideAttrs (finalAttrs: {
        version = "4.15";

        src = pkgs.fetchFromGitHub {
          owner = "aanderse";
          repo = "finit";
          rev = "373738f3d15a928ab8b37dcc2a3ac47df68db824";
          sha256 = "sha256-O7UgEWX55xzIEii5RB0F0qWk4UAl1n/F6ERF3GO/axA=";
        };

        buildInputs = finalAttrs.buildInputs ++ [ pkgs.libcap ];
      });
    };

  testScript = ''
    machine start

    machine expect "finix - stage 1"
    machine expect "finix - stage 2"
    machine expect "entering runlevel S"
    machine expect "entering runlevel 2"
    machine expect "getty on /dev/tty1"

    success
  '';
}
