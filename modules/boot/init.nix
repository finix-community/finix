{
  lib,
  ...
}:
{
  options.boot.init = {
    script = lib.mkOption {
      type = lib.types.path;
      readOnly = true;
      description = ''
        The generated init script for stage 2.
      '';
    };
  };
}
