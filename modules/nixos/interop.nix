{
  lib,
  config,
  ...
}:
{
  options.nixos = lib.mkOption {
    default = { };
    type = lib.types.submoduleWith {
      modules = [
        (
          { config, lib, ... }:
          {
            options.options = lib.mkOption {
              type = lib.types.listOf lib.types.deferredModule;
              default = [ ];
            };

            options.config = lib.mkOption {
              type = lib.types.submoduleWith {
                modules = config.options;
                class = "nixos";
              };
              default = { };
            };
          }
        )
      ];
    };
  };

  imports = [ config.nixos.config ];
}
