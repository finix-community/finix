{ ... }:
{
  config.testing.tests.nftables.nftables = {
    nodes.machine =
      { ... }:
      {
        services.mdevd.enable = true;
        services.nftables.enable = true;
      };

    testScript = ''
      machine.start()
      machine.wait_for_console_text("entering runlevel 2")

      with subtest("nftables task completes"):
          machine.wait_until_succeeds("initctl status nftables | grep -E 'done|running'", timeout=30)

      with subtest("inet filter table is loaded in kernel"):
          machine.wait_until_succeeds("nft list ruleset | grep -q 'inet filter'", timeout=15)
          ruleset = machine.succeed("nft list ruleset")
          assert "chain input" in ruleset, f"expected 'chain input', got: {ruleset}"

      machine.shutdown()
    '';
  };
}
