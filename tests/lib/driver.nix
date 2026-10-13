# finix test driver - extends nixos test driver with FinitMachine support
{ pkgs }:

let
  nixosTestDriver = pkgs.python3Packages.callPackage (pkgs.path + "/nixos/lib/test-driver") {
    nixosTests = { }; # stub, only used for passthru.tests
  };
in
nixosTestDriver.overrideAttrs (old: {
  pname = "finix-test-driver";

  postPatch = (old.postPatch or "") + ''
    cp ${./finit_machine.py} test_driver/finit_machine.py
    cp ${./qmp.py} test_driver/machine/qmp.py
    substituteInPlace test_driver/driver.py \
      --replace-fail '    QemuMachine,' '    # QemuMachine is provided by finit_machine below' \
      --replace-fail 'from test_driver.logger import AbstractLogger' \
        'from test_driver.finit_machine import FinitMachine as QemuMachine
from test_driver.logger import AbstractLogger'
  '';
})
