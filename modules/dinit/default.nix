{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.dinit;

  format = pkgs.formats.keyValue { };

  envFormat = pkgs.formats.keyValue {
    mkKeyValue = k: v: "${k}=${v}";
  };
in
{
  options.dinit = {
    user.services = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { config, name, ... }: {
            imports = [ ./common-options.nix ];

            config.env-file = lib.mkIf (config.environment != { }) (
              envFormat.generate "${name}.env" config.environment
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

  config = {
    environment.etc =
      let
        settingsFormat = import ./format.nix { inherit pkgs lib; };
        extraAttrs = [
          "enable"
          "environment"
          "path"
          "boot"
        ];


        userTree = lib.mapAttrs' (name: service: {
          name = "dinit.d/user/${name}";
          value.source = settingsFormat.generate name (builtins.removeAttrs service extraAttrs);
        }) (lib.filterAttrs (_: service: service.enable) cfg.user.services);

        systemTree = lib.mapAttrs' (name: service: {
          name = "dinit.d/${name}";
          value.source = settingsFormat.generate name (builtins.removeAttrs service extraAttrs);
        }) (lib.filterAttrs (_: service: service.enable) cfg.services);
      in
      userTree // systemTree // {
        "dinit.d/boot".source = settingsFormat.generate "boot" {
          type = "internal";
          "depends-on.d" = "boot.d";
        };
        "dinit.d/boot.d/.keep".text = "";
      };

    system.activation.scripts.dinitBootD = {
      deps = [ "etc" ];
      text = lib.concatMapStrings (
        name: "ln -sf ../${name} /etc/dinit.d/boot.d/${name}\n"
      ) (lib.attrNames (lib.filterAttrs (_: s: s.boot) cfg.services));
    };
  };
}
