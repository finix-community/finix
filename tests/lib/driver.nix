# finix test driver - extends nixos test driver with FinitMachine support
{ pkgs }:

let
  nixosTestDriver = pkgs.python314Packages.callPackage (pkgs.path + "/nixos/lib/test-driver") {
    nixosTests = { }; # stub, only used for passthru.tests
    extraPythonPackages = _pythonPackages: [ pkgs.python314Packages.qemu-qmp ];
  };
in
nixosTestDriver.overrideAttrs (old: {
  pname = "finix-test-driver";

  postPatch = (old.postPatch or "") + ''
        cp ${./finit_machine.py} test_driver/finit_machine.py
        cp ${./qmp_adapter.py} test_driver/machine/qmp.py
        substituteInPlace test_driver/driver.py \
          --replace-fail '    QemuMachine,' '    # QemuMachine is provided by finit_machine below' \
          --replace-fail 'from test_driver.logger import AbstractLogger' \
            'from test_driver.finit_machine import FinitMachine as QemuMachine
    from test_driver.logger import AbstractLogger'
  '';

  postCheck = (old.postCheck or "") + ''
    python -c \
      'from qemu.qmp.legacy import QEMUMonitorProtocol'
  '';
})
