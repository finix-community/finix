{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.dinit;

  format = pkgs.formats.keyValue { };
  settingsFormat = import ./format.nix { inherit pkgs lib; };
  extraAttrs = [
    "enable"
    "environment"
    "path"
  ];
in
{
  options.dinit = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to enable `dinit` as pid 1.
      '';
    };

    user.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to generate user level service configuration `/etc/dinit.d/user`.

        ::: {.note}
        Highly experimental, setting this option to `true` will not actually run any services, simply generate configuration.
        :::
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.dinit;
    };

    user.services = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { config, name, ... }: {
            imports = [ ./common-options.nix ];

            config.env-file = lib.mkIf (config.environment != { }) (
              format.generate "${name}.env" config.environment
            );
          }
        )
      );
      default = { };
      description = ''
        An attribute set of `dinit` user level services.

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html) for additional details.
      '';
    };

    services = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { config, name, ... }: {
            imports = [
              ./common-options.nix
              ./system-options.nix
            ];

            config.env-file = lib.mkIf (config.environment != { }) (
              format.generate "${name}.env" config.environment
            );
          }
        )
      );
      default = { };
      description = ''
        An attribute set of `dinit` system level services.

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html) for additional details.
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      boot.init = "${cfg.package}/bin/dinit";

      environment.etc = lib.mapAttrs' (name: service: {
        name = "dinit.d/${name}";
        value.source = settingsFormat.generate name (builtins.removeAttrs service extraAttrs);
      }) (lib.filterAttrs (_: service: service.enable) cfg.services);

      environment.systemPackages = [ cfg.package ];

      dinit.services.boot = {
        type = "internal";
      };
    })

    (lib.mkIf cfg.user.enable {
      environment.etc = lib.mapAttrs' (name: service: {
        name = "dinit.d/user/${name}";
        value.source = settingsFormat.generate name (builtins.removeAttrs service extraAttrs);
      }) (lib.filterAttrs (_: service: service.enable) cfg.user.services);
    })
  ];
}
