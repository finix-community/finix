{
  config,
  pkgs,
  lib,
  ...
}:
let
  envFormat = pkgs.formats.keyValue {
    mkKeyValue = k: v: "${k}=${toString v}";
  };

  serviceType =
    system:
    lib.types.attrsOf (
      lib.types.submodule (
        { config, name, ... }:
        {
          imports = [ ./common-options.nix ] ++ lib.optional system ./system-options.nix;

          config.env-file = lib.mkIf (config.environment != { }) (
            envFormat.generate "${name}.env" config.environment
          );
        }
      )
    );
in
{
  config = lib.mkIf (config.system.init == "dinit") {
    boot.init = lib.mkDefault "${config.dinit.package}/bin/dinit";
  };

  imports = [ ./targets.nix ];

  options.dinit = {
    user.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      defaultText = lib.literalExpression "true";
      description = "Whether to generate user-level dinit service files.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.dinit;
      defaultText = lib.literalExpression "pkgs.dinit";
      description = ''
        The dinit package to use.
      '';
    };

    user.services = lib.mkOption {
      type = serviceType false;
      default = { };
      description = ''
        An attribute set of `dinit` user level services.

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html) for additional details.
      '';
    };

    services = lib.mkOption {
      type = serviceType true;
      default = { };
      description = ''
        An attribute set of `dinit` system level services.

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html) for additional details.
      '';
    };
  };
}
