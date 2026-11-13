# finix test suite
#
# auto-discovers and exposes all tests in this directory and subdirectories.
# similar to nixos/tests/all-tests.nix in nixpkgs.
#
# usage:
#   nix-build tests                   # build all tests
#   nix-build tests -A boot           # build specific test
#   nix-build tests -A finit          # build test made of several files (finit/default.nix)
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

  # discover .nix files in the top-level directory
  topLevelTests =
    lib.mapAttrs'
      (filename: _: {
        name = lib.removeSuffix ".nix" filename;
        value = runTest (./. + "/${filename}");
      })
      (
        lib.filterAttrs (
          name: type: type == "regular" && lib.hasSuffix ".nix" name && !(builtins.elem name excludes)
        ) dirContents
      );

  # discover subdirectories (excluding lib and other excludes)
  subDirs = lib.filterAttrs (
    name: type: type == "directory" && !(builtins.elem name excludes)
  ) dirContents;

  # for each subdirectory:
  # - with a default.nix: a single test or a suite of tests
  # - otherwise: create a nested attrset of tests
  #   (e.g., foo/bar.nix -> foo.bar)
  # a suite's default.nix can either be:
  # - a function taking { pkgs, callTest }: returns an attrset of tests
  # - a plain composed test, passed through
  # use recurseIntoAttrs so nix-build recurses into subdirectories
  subDirTests = lib.mapAttrs (
    dirName: _:
    let
      subDir = ./. + "/${dirName}";
      suiteFile = subDir + "/default.nix";
      suite = import suiteFile;
    in
    lib.recurseIntoAttrs (
      if builtins.pathExists suiteFile then
        if builtins.isFunction suite then suite { inherit pkgs callTest; } else runTest suiteFile
      else
        lib.mapAttrs'
          (filename: _: {
            name = lib.removeSuffix ".nix" filename;
            value = runTest (subDir + "/${filename}");
          })
          (
            lib.filterAttrs (
              name: type:
              type == "regular"
              && lib.hasSuffix ".nix" name
              && !(builtins.elem name [
                "default.nix"
                "common.nix"
              ])
            ) (builtins.readDir subDir)
          )
    )
  ) subDirs;
in
topLevelTests // subDirTests
