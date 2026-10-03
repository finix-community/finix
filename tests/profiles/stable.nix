# test that the system boots successfully with the stable profile enabled
#
# a minimal test that just verifies the vm boots to runlevel 2.
# useful for isolating boot issues from test driver issues.
{
  name = "profiles.stable";

  nodes.machine =
    { ... }:
    {
      profiles.stable.enable = true;
    };

  testScript = ''
    machine.start()

    # wait for full boot sequence
    machine.wait_for_console_text("finix - stage 1")
    machine.wait_for_console_text("finix - stage 2")
    machine.wait_for_console_text("entering runlevel S")
    machine.wait_for_console_text("entering runlevel 2")
    machine.wait_for_console_text("getty on /dev/tty1")

    print("system booted to runlevel 2 successfully")

    machine.shutdown()
  '';
}
