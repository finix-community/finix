# finix test suite
#
# auto-discovers and exposes all tests in this directory.
# similar to nixos/tests/all-tests.nix in nixpkgs.
#
# usage:
#   nix-build tests              # build all tests
#   nix-build tests -A boot      # build specific test
#   nix-build tests -A tmpfiles  # build tmpfiles test
#
# interactive mode:
#   nix-build tests -A boot.driverInteractive
#   ./result/bin/finix-test-driver
{
  pkgs ?
    let
      sources = import ../lon.nix;
    in
    import sources.nixpkgs { },

  # callTest wraps mkTest - allows caller to customize test invocation
  # default is null, meaning use the standard testLib.mkTest
  callTest ? null,
}:
let
  inherit (pkgs) lib;

  testLib = import ./lib { inherit lib pkgs; };
  runTest = if callTest != null then callTest else (file: testLib.mkTest (import file));

  # files/directories to exclude from auto-discovery
  excludes = [
    "default.nix"
    "lib"
  ];

  testFiles = lib.filterAttrs (
    name: type: type == "regular" && lib.hasSuffix ".nix" name && !(builtins.elem name excludes)
  ) (builtins.readDir ./.);
in
lib.mapAttrs' (filename: _: {
  name = lib.removeSuffix ".nix" filename;
  value = runTest (./. + "/${filename}");
}) testFiles
