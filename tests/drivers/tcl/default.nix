{
  lib,
  pkgs,
}:

let
  finixModules = import ../../../modules;
  qemu-common = import (pkgs.path + /nixos/lib/qemu-common.nix) { inherit lib pkgs; };

  mkRootImage = pkgs.callPackage ../../make-ext2-fs.nix {
    qemu = pkgs.qemu_test;
  };

  mkVm =
    name: nodeConfig:
    lib.evalModules {
      specialArgs = {
        inherit pkgs;
      };
      modules = [
        ../../../modules/testing
        ../../../modules/virtualisation/qemu.nix
        nodeConfig
        (
          { config, ... }:
          {
            boot.kernelParams = [
              "console=ttyS0,115200n8"
            ];
            fileSystems."/" = {
              device = "/dev/disk/by-label/${name}-test";
              fsType = "ext2";
            };
            testing = {
              enable = true;
              driver = "tcl";
            };
            virtualisation.qemu.package = pkgs.qemu_test;
          }
        )
      ] ++ lib.attrValues finixModules;
    };

  mkRootImage' =
    name: config:
    mkRootImage {
      storePaths = [
        config.system.topLevel
      ];
      format = "qcow2";
      volumeLabel = "${name}-test";
    };

  # Emit a Tcl script that declares a test node.
  createNodeScript =
    name: config:
    let
      # monPtyPath = "${name}.mon.pty";
      monitorPath = "${name}.monitor";
    in
    ''
      CreateNode ${name} {
        exec -ignorestderr ${config.virtualisation.qemu.package}/bin/qemu-img create \
          -f qcow2 -b {${mkRootImage' name config}/image.qcow2} \
          -F qcow2 {${name}.root.qcow2}
        variable spawnCmd
        lappend spawnCmd ${config.virtualisation.qemu.argv |> map (s: "{${s}}") |> toString}
        lappend spawnCmd -name {${name}}
        lappend spawnCmd -drive {file=${name}.root.qcow2}
        lappend spawnCmd -serial mon:stdio
      }
    '';

in
{
  mkTest =
    {
      # Name of test.
      name,

      # Attrset of test machines.
      nodes,

      # Script to run in the Expect interpreter.
      tclScript,

      # Timeout for expect commands.
      expectTimeout ? 10,
      ...
    }:
    let
      nodes' = lib.mapAttrs mkVm nodes;
    in
    rec {
      nodes = nodes';
      script = pkgs.writeTextFile {
        name = "test-${name}.tcl";
        executable = true;
        text = ''
          #!${lib.getExe pkgs.expect} -f
          source ${./driver.tcl}
          set testName {${name}}
          set timout {${toString expectTimeout}}

          ${lib.concatMapStrings (name: createNodeScript name nodes.${name}.config) (
            builtins.attrNames nodes
          )}

          namespace import testNodes::*

          ${tclScript}

          fail "test script fell thru"
        '';
      };
      run = pkgs.runCommand "test-${name}.log" { } script;
    };
}
