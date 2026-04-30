{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.micro;
in
{
  options.programs.micro = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [micro](${pkgs.micro.meta.homepage}).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.micro;
      defaultText = lib.literalExpression "pkgs.micro";
      description = ''
        The package to use for `micro`.
      '';
    };

    defaultEditor = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to configure [micro](${pkgs.micro.meta.homepage}) as the
        default editor using the `EDITOR` environment variable.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    security.pam.environment = lib.optionalAttrs cfg.defaultEditor {
      EDITOR.default = lib.mkOverride 900 cfg.package.meta.mainProgram;
    };
  };
}
