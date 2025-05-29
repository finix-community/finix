{
  pkgs ? import <nixpkgs> {
    overlays = [ (import ../overlays/default.nix) ];
  },
}:
let
  inherit (pkgs) lib;
  testArgs.testenv = import ./testenv { inherit pkgs; };
in
with builtins;
readDir ./.
|> attrNames
|> filter (x: !(elem x [ "default.nix" "testenv" ])) 
|> map (p: {
  name = lib.removeSuffix ".nix" p;
  value = import ./${p} testArgs;
}) |> listToAttrs
