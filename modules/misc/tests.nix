{ lib, ... }:
{
  options.testing.tests = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.attrsOf (
        lib.types.submodule {
          options = {
            nodes = lib.mkOption {
              type = lib.types.attrsOf lib.types.deferredModule;
              default = { };
            };
            testScript = lib.mkOption {
              type = lib.types.raw;
            };
            extraDriverArgs = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
            };
          };
        }
      )
    );
    default = { };
  };
}
