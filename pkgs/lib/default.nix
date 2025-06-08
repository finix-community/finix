lib: prev:

{
  generators = prev.generators // {
    toPreserves = import ./generators/preserves.nix { inherit lib; };
  };
}
