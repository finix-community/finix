# backdoor shell service for test driver communication
#
# this module provides a root shell accessible via virtconsole (/dev/hvc0),
# allowing the test driver to execute commands inside the vm
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.testing;

  # backdoor script based on NixOS test-instrumentation.nix
  # runs a non-interactive bash that reads commands from /dev/hvc0
  backdoorScript = pkgs.writeShellScript "backdoor" ''
    export USER=root
    export HOME=/root
    # use the system path (same as /run/current-system/sw) to get all environment.systemPackages
    export PATH=${lib.makeBinPath [ config.environment.path ]}

    # source profile if it exists
    if [[ -e /etc/profile ]]; then
      source /etc/profile 2>/dev/null || true
    fi

    # don't use a pager - commands are non-interactive
    export PAGER=

    cd /tmp

    # wait for hvc0 to be available
    while [[ ! -e /dev/hvc0 ]]; do
      sleep 0.1
    done

    # redirect stdin/stdout to virtio console
    exec < /dev/hvc0 > /dev/hvc0

    # wait for ttyS0 to be available, then redirect stderr to serial console
    # this matches NixOS behavior and avoids escape sequences from programs
    # like initctl being sent back through the backdoor
    while ! exec 2> /dev/ttyS0; do
      sleep 0.1
    done
    echo "connecting to host..." >&2

    # set raw mode to prevent CR/LF conversion
    stty -F /dev/hvc0 raw -echo

    # signal to test driver that shell is ready
    # NixOS test driver expects this exact message (capital S)
    echo "Spawning backdoor root shell..."

    # run a non-interactive bash that reads commands from /dev/hvc0
    # passing the device as argument makes bash run non-interactively
    # (avoids terminal control issues)
    PS1="" exec ${pkgs.bashNonInteractive}/bin/bash --norc /dev/hvc0
  '';

in
{
  options.testing.backdoor.enable = lib.mkEnableOption "backdoor shell service" // {
    default = true;
  };

  config = lib.mkIf (cfg.enable && cfg.backdoor.enable) {
    # ensure virtio_console module is loaded early
    boot.initrd.kernelModules = [ "virtio_console" ];

    environment.systemPackages = [
      pkgs.iproute2
      pkgs.iputils
    ];

    # backdoor service for finit
    finit.services.backdoor = {
      description = "test driver backdoor shell";
      command = backdoorScript;
      runlevels = "234";
      log = false;

      # the backdoor runs bash which executes commands from hvc0 until EOF, then exits
      restart = 0;
    };
  };
}
