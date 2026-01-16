{
  testenv ? import ./testenv { },
}:

testenv.mkTest {
  name = "finit";

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

    machine expect "finix - stage 1"
    machine expect "finix - stage 2"
    machine expect "entering runlevel S"
    machine expect "entering runlevel 2"
    machine expect "getty on /dev/tty1"

    success
  '';
}
