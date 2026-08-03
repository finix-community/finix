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

      The selected init backend supplies the default stage-2 init executable
      and renders its service configuration.
    '';
  };
}
