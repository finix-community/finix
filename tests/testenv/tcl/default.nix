{
  lib,
  pkgs,
}:
let
  finixModules = import ../../../modules;

  mkRootImage = pkgs.callPackage ../make-ext2-fs.nix {
    qemu = pkgs.qemu_test;
  };

  mkVm =
    nodes: name: nodeConfig:
    lib.evalModules {
      specialArgs = {
        inherit nodes;

        modulesPath = toString (pkgs.path + "/nixos/modules");
      };
      modules = [
        ../../../modules/testing
        ../../../modules/virtualisation/qemu.nix
        nodeConfig
        (
          { config, ... }:
          {
            # TODO: option should provide a default
            nixpkgs.pkgs = pkgs;

            boot.kernelParams = [
              "console=ttyS0,115200n8"
            ];
            fileSystems."/" =
              if config.testing.enableRootDisk then
                {
                  device = "/dev/disk/by-label/${name}-test";
                  fsType = "ext2";
                }
              else
                {
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
      ]
      ++ lib.attrValues finixModules;
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

  # emit a tcl script that declares a test node
  createNodeScript =
    name: config:
    let
      vlan = config.testing.network.vlan;
      mac = config.testing.network.mac;
    in
    ''
      CreateNode ${name} {
        variable spawnCmd
        variable stateDir
        variable backdoorEnabled

        # track if backdoor is enabled for this node (for better error messages)
        set backdoorEnabled ${if config.testing.backdoor.enable then "1" else "0"}

        # set up state directory for sockets
        set stateDir [file join [pwd] "vm-state-${name}"]
        file mkdir $stateDir

        # base qemu command from nix configuration
        lappend spawnCmd ${toString (map (s: "{${s}}") config.virtualisation.qemu.argv)}
        lappend spawnCmd -name {${name}}

        # vde networking - uses global vdeSockDir variable set before nodes are spawned
        lappend spawnCmd -device "virtio-net-pci,netdev=vlan${toString vlan},mac=${mac}"
        lappend spawnCmd -netdev "vde,id=vlan${toString vlan},sock=$vdeSockDir"

        ${lib.optionalString config.testing.backdoor.enable ''
          # add virtio-serial bus for shell backdoor
          lappend spawnCmd -device {virtio-serial}

          # shell backdoor socket (connects to /dev/hvc0 in guest via virtconsole)
          lappend spawnCmd -chardev "socket,id=shell,path=$stateDir/shell.sock,server=on,wait=off"
          lappend spawnCmd -device {virtconsole,chardev=shell}
        ''}

        ${lib.optionalString config.testing.enableRootDisk ''
          exec -ignorestderr ${config.virtualisation.qemu.package}/bin/qemu-img create \
            -f qcow2 -b {${mkRootImage' name config}/image.qcow2} \
            -F qcow2 {${name}.root.qcow2}
          lappend spawnCmd -drive {file=${name}.root.qcow2}
        ''}
      }
    '';

in
{
  mkTest =
    {
      # name of test
      name,

      # attrset of test machines
      nodes,

      # script to run in the expect interpreter
      testScript,

      runAttrs ? { },

      # timeout for expect commands
      expectTimeout ? 10,
      ...
    }:
    let
      nodes' = lib.mapAttrs (mkVm nodes') nodes;
      script = pkgs.writeTextFile {
        name = "test-${name}.tcl";
        executable = true;
        text = ''
          #!${lib.getExe pkgs.expect} -f
          source ${./driver.tcl}
          set testName {${name}}
          set timeout ${toString expectTimeout}

          # ================================================================
          # cleanup and signal handling
          # ================================================================

          # track spawned processes for cleanup
          set spawnedPids {}

          # cleanup procedure - kills spawned processes
          proc cleanup {} {
            global spawnedPids
            foreach pid $spawnedPids {
              catch {exec kill -9 $pid}
            }
            # also try to close any vde switch
            global vdeSpawnId
            if {[info exists vdeSpawnId] && $vdeSpawnId ne ""} {
              catch {close -i $vdeSpawnId}
              catch {exec kill -9 [exp_pid -i $vdeSpawnId]}
            }
          }

          # signal handler for graceful shutdown
          proc signalHandler {sig} {
            log "received signal $sig, cleaning up..."
            cleanup
            exit 1
          }

          # register signal handlers
          trap signalHandler {SIGINT SIGTERM}

          # register cleanup on exit (for any exit path)
          rename exit _real_exit
          proc exit {{code 0}} {
            cleanup
            _real_exit $code
          }

          # ================================================================
          # vde networking setup
          # ================================================================

          # global variable for vde socket directory (used by node spawn)
          set vdeSockDir [file join [pwd] "vde1.ctl"]

          # start vde switch before spawning vms
          # --dirmode 0700 sets permissions at creation (works in nix sandbox)
          # --hub floods packets to all ports (needed for vlan tagged traffic)
          # use spawn to keep the process alive (keeps stdin open)
          log "starting vde switch..."
          log_user 0
          spawn vde_switch --sock $vdeSockDir --dirmode 0700 --hub
          set vdeSpawnId $spawn_id
          log_user 1

          # validate spawn succeeded
          if {$vdeSpawnId eq "" || $vdeSpawnId < 0} {
            testFail "failed to spawn vde switch"
          }

          # wait for vde control socket to appear
          set deadline [expr {[clock seconds] + 5}]
          while {![file exists "$vdeSockDir/ctl"] && [clock seconds] < $deadline} {
            after 100
          }
          if {![file exists "$vdeSockDir/ctl"]} {
            testFail "vde switch failed to start (no ctl socket)"
          }
          log "vde switch started: $vdeSockDir"

          ${lib.concatMapStrings (nodeName: createNodeScript nodeName nodes'.${nodeName}.config) (
            lib.attrNames nodes'
          )}

          namespace import testNodes::*

          ${if lib.isFunction testScript then testScript { nodes = nodes'; } else testScript}

          testFail "test script fell thru without calling success"
        '';
      };
      testDeps = [
        pkgs.socat # for unix socket connections from tcl
        pkgs.coreutils # for base64 decoding in shellExecute
        pkgs.vde2 # for vde virtual networking
        pkgs.expect # for the test driver itself
      ];

      # interactive driver script - runs the test with tty for shell interaction
      driverInteractive = pkgs.writeShellScriptBin "test-${name}-interactive" ''
        set -e
        unset out  # prevent driver.tcl from trying to log to nix-shell's $out
        export PATH="${lib.makeBinPath testDeps}:$PATH"

        # create temp directory for test state
        TMPDIR=$(mktemp -d -t finix-test-${name}.XXXXXX)
        trap "rm -rf $TMPDIR" EXIT
        cd "$TMPDIR"

        echo "Starting interactive test: ${name}"
        echo "Working directory: $TMPDIR"
        echo ""

        # run the test script directly with tty
        exec ${script}
      '';

      # a script to just boot and drop into interactive shell (no test script)
      interactiveShell = pkgs.writeTextFile {
        name = "test-${name}-shell.tcl";
        executable = true;
        text = ''
          #!${lib.getExe pkgs.expect} -f
          source ${./driver.tcl}
          set testName {${name}}
          set timeout 60

          # start vde switch
          set vdeSockDir [file join [pwd] "vde1.ctl"]
          log "starting vde switch..."
          log_user 0
          spawn vde_switch --sock $vdeSockDir --dirmode 0700 --hub
          set vdeSpawnId $spawn_id
          log_user 1
          set deadline [expr {[clock seconds] + 5}]
          while {![file exists "$vdeSockDir/ctl"] && [clock seconds] < $deadline} {
            after 100
          }
          if {![file exists "$vdeSockDir/ctl"]} {
            testFail "vde switch failed to start (no ctl socket)"
          }
          log "vde switch started: $vdeSockDir"

          ${lib.concatMapStrings (nodeName: createNodeScript nodeName nodes'.${nodeName}.config) (
            lib.attrNames nodes'
          )}

          namespace import testNodes::*

          # just start the first node and drop into interactive shell
          ${lib.head (lib.attrNames nodes')} start
          log "waiting for boot..."
          # wait for backdoor to connect (this message appears on serial console)
          # note: "spawning backdoor root shell..." goes to hvc0, not the console
          ${lib.head (lib.attrNames nodes')} expect {connecting to host...}
          ${lib.head (lib.attrNames nodes')} shellInteract
        '';
      };

      # interactive shell driver - just boots and gives you a shell
      interactive = pkgs.writeShellScriptBin "test-${name}-shell" ''
        set -e
        unset out  # prevent driver.tcl from trying to log to nix-shell's $out
        export PATH="${lib.makeBinPath testDeps}:$PATH"

        TMPDIR=$(mktemp -d -t finix-test-${name}.XXXXXX)
        trap "rm -rf $TMPDIR" EXIT
        cd "$TMPDIR"

        echo "starting interactive shell for: ${name}"
        echo "the vm will boot and you'll get a shell"
        echo "press Ctrl+D to exit the shell"
        echo ""

        exec ${interactiveShell}
      '';

      runAttrs' = runAttrs // {
        nativeBuildInputs = runAttrs.nativeBuildInputs or [ ] ++ testDeps;

        passthru = runAttrs.passthru or { } // {
          nodes = nodes';
          inherit script driverInteractive interactive;
        };
      };
    in
    pkgs.runCommand "test-${name}.log" runAttrs' script;
}
