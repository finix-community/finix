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
    export PATH=${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.gnugrep
        pkgs.gnused
        pkgs.findutils
        pkgs.netcat
        pkgs.iproute2
        pkgs.iputils
      ]
    }:$PATH

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

    # redirect stdin/stdout/stderr to virtio console
    # this ensures all command output (including help text which often goes to stderr)
    # is visible through the backdoor socket
    exec < /dev/hvc0 > /dev/hvc0 2>&1

    # wait for ttyS0 to be available for the "connecting to host..." message
    deadline=$((SECONDS + 10))
    while [[ ! -e /dev/ttyS0 ]]; do
      if [[ $SECONDS -ge $deadline ]]; then
        echo "warning: ttyS0 not available after 10s"
        break
      fi
      sleep 0.1
    done
    # send connect message to serial console if available
    [[ -e /dev/ttyS0 ]] && echo "connecting to host..." > /dev/ttyS0

    # set raw mode to prevent CR/LF conversion
    stty -F /dev/hvc0 raw -echo

    # signal to test driver that shell is ready
    # this exact message is expected by the test driver
    echo "spawning backdoor root shell..."

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
