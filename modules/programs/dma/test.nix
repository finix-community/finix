{ ... }:
{
  config.testing.tests.dma.dma = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.cron.enable = true;
        programs.dma.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("sendmail setgid wrapper exists"):
          machine.succeed("test -f /run/wrappers/bin/sendmail")
          machine.succeed("test -g /run/wrappers/bin/sendmail")

      with subtest("dma configuration is installed"):
          machine.succeed("test -f /etc/dma/dma.conf")

      with subtest("mail spool directory exists"):
          machine.succeed("test -d /var/spool/dma")

      machine.shutdown()
    '';
  };
}
