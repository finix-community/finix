let
  # order matters
  parts = map import [
    ./tmpfiles.nix
    ./remain-after-exit.nix
  ];

  runPart =
    nodes: part:
    if builtins.isFunction part.testScript then part.testScript { inherit nodes; } else part.testScript;
in
{
  name = "finit";

  nodes.machine =
    { ... }:
    {
      imports = map (part: part.nodes.machine) parts;

      services.getty.enable = true;
      services.mdevd.enable = true;
    };

  testScript =
    { nodes }:
    ''
      machine.start()

      # wait for full boot sequence
      machine.wait_for_console_text("finix - stage 1")
      machine.wait_for_console_text("finix - stage 2")
      machine.wait_for_console_text("entering runlevel S")
      machine.wait_for_console_text("entering runlevel 2")

      ${builtins.concatStringsSep "\n" (map (runPart nodes) parts)}

      with subtest("shutdown"):
          machine.shutdown()
    '';
}
