# finix test driver - extends nixos test driver with FinitMachine support
{ pkgs }:

let
  nixosTestDriver = pkgs.callPackage (pkgs.path + "/nixos/lib/test-driver") {
    nixosTests = { }; # stub, only used for passthru.tests
  };
in
nixosTestDriver.overrideAttrs (old: {
  pname = "finix-test-driver";

  postPatch = (old.postPatch or "") + ''
    cp ${./finit_machine.py} test_driver/finit_machine.py
  '';
})
