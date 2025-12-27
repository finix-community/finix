# tests for the finix test driver itself
#
# these tests verify that the test driver (tcl/expect based) works correctly,
# similar to nixos/tests/nixos-test-driver/ in nixpkgs.
#
# to run all tests:
#   nix-build tests/finix-test-driver
#
# to run a specific test:
#   nix-build tests/finix-test-driver -A shell
#   nix-build tests/finix-test-driver -A multi-node
{
  testenv ? import ../testenv { },
}:
{
  boot = testenv.mkTest (import ./boot.nix);
  shell = testenv.mkTest (import ./shell.nix);
  multi-node = testenv.mkTest (import ./multi-node.nix);
}
