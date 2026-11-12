# test that nixos-facter detects virtualisation inside a vm
{
  name = "facter-virtualisation";

  nodes.machine =
    { pkgs, ... }:
    {
      services.getty.enable = true;
      services.mdevd.enable = true;

      environment.systemPackages = [ pkgs.nixos-facter ];
    };

  testScript = ''
    import json

    machine.start()
    machine.wait_for_console_text("entering runlevel 2")

    report = json.loads(machine.succeed("nixos-facter"))

    virt = report.get("virtualisation")
    print(f"facter detected virtualisation: {virt}")

    assert virt != "none", "facter failed to detect virtualisation inside a vm"

    machine.shutdown()
  '';
}
