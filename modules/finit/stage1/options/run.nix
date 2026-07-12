{ lib }:
{
  options.priority = lib.mkOption {
    type = lib.types.int;
    default = 1000;
    description = ''
      Order of this `run` command in relation to the others. The semantics are the same as
      with `lib.mkOrder`. Smaller values have a greater priority.
    '';
  };
}
