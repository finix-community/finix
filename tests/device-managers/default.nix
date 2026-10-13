# Device-manager test suite entry point
{
  pkgs ?
    let
      sources = import ../../lon.nix;
    in
    import sources.nixpkgs { },
  callTest ? null,
}:
let
  lib = pkgs.lib;
  testLib = import ../lib { inherit lib pkgs; };
  runTest = if callTest != null then callTest else (file: testLib.mkTest (import file));
in
{
  mdevd = runTest ./mdevd.nix;
}
