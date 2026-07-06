{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.xinit;
in
{
  imports = [ ./test.nix ];

  options.programs.xinit = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [xinit](${pkgs.xinit.meta.homepage}).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default =
        (pkgs.xinit.override {
          xorg-server = config.programs.xorg.package or pkgs.xorg-server;
        }).overrideAttrs
          (
            o:
            lib.optionalAttrs config.security.wrappers.X.enable or false {
              # TODO: replace once https://github.com/NixOS/nixpkgs/pull/534421 is merged
              configureFlags = o.configureFlags or [ ] ++ [
                "--with-xserver=${config.security.wrapperDir}/X"
              ];
            }
          );
      defaultText = lib.literalExpression "pkgs.xinit";
      description = ''
        The package to use for `xinit`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
  };
}
