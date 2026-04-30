{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.nano;
in
{
  options.programs.nano = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [nano](${pkgs.nano.meta.homepage}).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nano;
      defaultText = lib.literalExpression "pkgs.nano";
      description = ''
        The package to use for `nano`.
      '';
    };

    defaultEditor = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to configure [nano](${pkgs.nano.meta.homepage}) as the
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
