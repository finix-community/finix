# finix test suite
#
# auto-discovers and exposes all tests in this directory and subdirectories.
# similar to nixos/tests/all-tests.nix in nixpkgs.
#
# usage:
#   nix-build tests                   # build all tests
#   nix-build tests -A boot           # build specific test
#   nix-build tests -A finit.tmpfiles # build test from subdirectory
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

  dirContents = builtins.readDir ./.;

  missingTests = lib.attrNames (
    lib.filterAttrs (name: _: !(builtins.hasAttr name registry)) (builtins.removeAttrs finixModules [ "default" ])
  );

in
lib.throwIfNot (callTest != null || missingTests == [ ])
  "The following modules are missing tests: ${lib.concatStringsSep ", " missingTests}"
  (
    lib.foldlAttrs (
      acc: moduleName: tests:
      acc
      // lib.mapAttrs (
        testName: test: runTest (test // { name = "${moduleName}-${testName}"; })
      ) tests
    ) { } registry
  )
