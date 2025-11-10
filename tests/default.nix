let
  testArgs.testenv = import ./testenv { };
  inherit (testArgs.testenv.pkgs) lib;
in
with builtins;
readDir ./.
|> attrNames
|> filter (
  x:
  !(elem x [
    "default.nix"
    "testenv"
  ])
)
|> map (p: {
  name = lib.removeSuffix ".nix" p;
  value = import ./${p} testArgs;
})
|> listToAttrs
