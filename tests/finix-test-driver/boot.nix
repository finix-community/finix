# test that the system boots successfully
#
# a minimal test that just verifies the vm boots to runlevel 2
# useful for isolating boot issues from test driver issues
{
  name = "finix-test-driver.boot";

  nodes.machine = {
    finit.runlevel = 2;
    services.mdevd.enable = true;
  };

  testScript = ''
    machine start
    machine expect "entering runlevel 2"

    log "system booted to runlevel 2 successfully"

    success
  '';
}
