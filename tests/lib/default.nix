# finix test driver library
#
# provides mkTest function for creating VM-based tests.
# uses NixOS test driver with finit-specific extensions.
{
  pkgs,
  lib,
}:
let
  finixModules = import ../../modules;

  # build the nixos test driver with FinitMachine class
  testDriver = import ./driver.nix { inherit pkgs; };

  # evaluate a finix VM configuration
  mkVm =
    nodes: name: nodeConfig:
    lib.evalModules {
      specialArgs = {
        inherit nodes;
        modulesPath = toString (pkgs.path + "/nixos/modules");
      };
      modules = [
        ./testing.nix
        ../../modules/virtualisation/qemu.nix
        nodeConfig
        {
          nixpkgs.pkgs = pkgs;

          boot.kernelParams = [
            "console=ttyS0,115200n8"
          ];

          # tmpfs root - /nix/store is mounted via 9p from host
          fileSystems."/" = {
            device = "tmpfs";
            fsType = "tmpfs";
            options = [ "mode=755" ];
          };

          networking.hostName = name;

          testing.enable = true;

          virtualisation.qemu.package = pkgs.qemu_test;
        }
      ]
      ++ lib.attrValues finixModules;
    };

  # create a vm start script compatible with nixos test driver
  mkVmScript =
    name: config:
    let
      qemuArgs = config.virtualisation.qemu.argv;
      vlan = config.testing.network.vlan;
      mac = config.testing.network.mac;
    in
    pkgs.writeShellScript "run-${name}-vm" ''
      set -e

      if [ -n "$TMPDIR" ]; then
        mkdir -p "$TMPDIR"
        cd "$TMPDIR"
      fi

      if [ -n "$SHARED_DIR" ]; then
        mkdir -p "$SHARED_DIR"
      fi

      exec ${lib.escapeShellArgs qemuArgs} \
        -name "${name}" \
        -device "virtio-net-pci,netdev=vlan${toString vlan},mac=${mac}" \
        -netdev "vde,id=vlan${toString vlan},sock=$TMPDIR/../vde${toString vlan}.ctl" \
        "$@"
    '';

  # create the vm derivation with start script
  mkVmDerivation =
    name: config:
    pkgs.runCommand "finix-vm-${name}"
      {
        preferLocalBuild = true;
        meta.mainProgram = "run-${name}-vm";
      }
      ''
        mkdir -p $out/bin
        ln -s ${config.system.topLevel} $out/system
        ln -s ${mkVmScript name config} $out/bin/run-${name}-vm
      '';

in
{
  inherit testDriver pkgs lib;

  mkTest =
    {
      name,
      nodes,
      testScript,
      extraDriverArgs ? [ ],
      ...
    }:
    let
      # evaluate all node configurations
      evaluatedNodes = lib.mapAttrs (mkVm evaluatedNodes) nodes;

      # create vm derivations
      vms = lib.mapAttrs (nodeName: nodeEval: mkVmDerivation nodeName nodeEval.config) evaluatedNodes;

      # get list of vm start scripts
      vmStartScripts = lib.mapAttrsToList (name: vm: "${vm}/bin/run-${name}-vm") vms;

      # get unique vlans
      vlans = lib.unique (
        lib.mapAttrsToList (_: nodeEval: nodeEval.config.testing.network.vlan) evaluatedNodes
      );

      # generate python test script
      testScriptString =
        if builtins.isFunction testScript then testScript { nodes = evaluatedNodes; } else testScript;

      pythonTestScript = pkgs.writeText "test-${name}.py" testScriptString;

      # build the test driver wrapper
      driver =
        pkgs.runCommand "finix-test-driver-${name}"
          {
            nativeBuildInputs = [ pkgs.makeWrapper ];
            buildInputs = [ testDriver ];
            passthru = {
              inherit vms evaluatedNodes;
              nodes = evaluatedNodes;
            };
            meta.mainProgram = "finix-test-driver";
          }
          ''
            mkdir -p $out/bin
            cp ${pythonTestScript} $out/test-script
            makeWrapper ${testDriver}/bin/nixos-test-driver $out/bin/finix-test-driver \
              --set startScripts "${lib.concatStringsSep " " vmStartScripts}" \
              --set testScript "$out/test-script" \
              --set vlans "${toString vlans}" \
              ${lib.escapeShellArgs (
                lib.concatMap (arg: [
                  "--add-flags"
                  arg
                ]) extraDriverArgs
              )}
          '';

      # run the test - vde switches are managed by the test driver's vlan.py
      test =
        pkgs.runCommand "finix-test-${name}"
          {
            requiredSystemFeatures = [ "kvm" ];
            nativeBuildInputs = [ pkgs.vde2 ];
            passthru = {
              inherit driver vms;
              driverInteractive = driver;
            };
          }
          ''
            mkdir -p $out
            export LOGFILE=/dev/null
            ${driver}/bin/finix-test-driver -o $out
          '';

    in
    test;
}
