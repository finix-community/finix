# test for multi-vm functionality
#
# this test verifies that multiple vms can be started and communicate
# with each other via the virtual network.
{
  name = "finix-test-driver.multi-node";

  nodes.client = {
    boot.serviceManager = "finit";

    finit.runlevel = 2;
    services.mdevd.enable = true;
  };

  nodes.server = {
    boot.serviceManager = "finit";

    finit.runlevel = 2;
    services.mdevd.enable = true;
  };

  testScript = ''
    subtest "startAll starts all nodes" {
      startAll
    }

    # Wait for both VMs to boot and network to be configured
    # The test-network run unit depends on coldplug and syslogd, then configures eth0
    client expect "entering runlevel 2"
    server expect "entering runlevel 2"

    # Wait for test-network run unit to complete
    client waitForCondition "task/test-network/success" 30
    server waitForCondition "task/test-network/success" 30

    subtest "nodes have correct ips" {
      set clientIp [client succeed "ip addr show eth0"]
      if {![string match "*192.168.1.1*" $clientIp]} {
        error "client doesn't have expected ip 192.168.1.1"
      }

      set serverIp [server succeed "ip addr show eth0"]
      if {![string match "*192.168.1.2*" $serverIp]} {
        error "server doesn't have expected ip 192.168.1.2"
      }
    }

    subtest "ping by ip" {
      client succeed "ping -c 3 192.168.1.2"
      server succeed "ping -c 3 192.168.1.1"
    }

    subtest "ping by hostname" {
      client succeed "ping -c 1 server"
      server succeed "ping -c 1 client"
    }

    subtest "shutdown" {
      client shutdown 60
      server shutdown 60
    }

    success
  '';
}
