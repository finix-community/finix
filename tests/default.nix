{
  pkgs ?
    let
      sources = import ../lon.nix;
    in
    import sources.nixpkgs { },

  callTest ? null,
}:
let
  inherit (pkgs) lib;

  testLib = import ./lib { inherit lib pkgs; };
  runTest = if callTest != null then callTest else testLib.mkTest;

  finixModules = import ../modules;
  eval = lib.evalModules {
    modules = [
      finixModules.default
      ../modules/virtualisation
      { config.nixpkgs.pkgs = pkgs; }
    ]
    ++ lib.attrValues (builtins.removeAttrs finixModules [ "default" ]);
    specialArgs = {
      modules = finixModules;
    };
  };

  registry = eval.config.testing.tests;

  missingTests = lib.attrNames (
    lib.filterAttrs (name: _: !(builtins.hasAttr name registry)) (
      builtins.removeAttrs finixModules [ "default" ]
    )
  );

in
lib.throwIfNot (callTest != null || missingTests == [ ])
  "The following modules are missing tests: ${lib.concatStringsSep ", " missingTests}"
  (
    lib.foldlAttrs (
      acc: moduleName: tests:
      acc
      // lib.mapAttrs (testName: test: runTest (test // { name = "${moduleName}-${testName}"; })) tests
    ) { } registry
  )
