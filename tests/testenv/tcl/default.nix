{
  lib,
  pkgs,
}:

let
  inherit (lib)
    optionalString;

  finixModules = import ../../../modules;
  qemu-common = import (pkgs.path + /nixos/lib/qemu-common.nix) { inherit lib pkgs; };

  mkRootImage = pkgs.callPackage ../make-ext2-fs.nix {
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
            fileSystems."/" =
              if config.testing.enableRootDisk
              then {
                device = "/dev/disk/by-label/${name}-test";
                fsType = "ext2";
              } else {
                device = "tmpfs";
                fsType = "tmpfs";
                options = [ "mode=755" ];
              };
            networking.hostName = name;
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
        variable spawnCmd
        lappend spawnCmd ${config.virtualisation.qemu.argv |> map (s: "{${s}}") |> toString}
        lappend spawnCmd -name {${name}}
        ${optionalString config.testing.enableRootDisk ''

          exec -ignorestderr ${config.virtualisation.qemu.package}/bin/qemu-img create \
            -f qcow2 -b {${mkRootImage' name config}/image.qcow2} \
            -F qcow2 {${name}.root.qcow2}
          lappend spawnCmd -drive {file=${name}.root.qcow2}
        ''}
      }
    '';

in
{
  inherit lib pkgs;
  mkTest =
    {
      # Name of test.
      name,

      # Attrset of test machines.
      nodes,

      # Script to run in the Expect interpreter.
      tclScript,

      runAttrs ? { },

      # Timeout for expect commands.
      expectTimeout ? 10,
      ...
    }:
    let
      nodes' = lib.mapAttrs mkVm nodes;
      script = pkgs.writeTextFile {
        name = "test-${name}.tcl";
        executable = true;
        text = ''
          #!${lib.getExe pkgs.expect} -f
          source ${./driver.tcl}
          set testName {${name}}
          set timout {${toString expectTimeout}}

          ${lib.concatMapStrings (name: createNodeScript name nodes'.${name}.config) (
            builtins.attrNames nodes'
          )}

          namespace import testNodes::*

          ${if builtins.isFunction tclScript
            then tclScript { nodes = nodes'; }
            else tclScript
          }

          fail "test script fell thru"
        '';
      };
      run = pkgs.runCommand "test-${name}.log" runAttrs script;
    in run // {
      nodes = nodes';
      inherit script;
    };
}
