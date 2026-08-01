{ lib, ... }:
{
  options.system.init = lib.mkOption {
    type = lib.types.enum [
      "finit"
      "dinit"
    ];
    default = "finit";
    description = ''
      The init system used as stage-2 PID 1.

      Service modules should put init-system-specific definitions in a
      backend module selected by this option.
    '';
  };
}
