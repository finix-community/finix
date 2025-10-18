{ config, pkgs, lib, ... }:
let
  cfg = config.services.earlyoom;
in
{
  options.services.earlyoom = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [earlyoom](${pkgs.earlyoom.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.earlyoom;
      defaultText = lib.literalExpression "pkgs.earlyoom";
      description = ''
        The package to use for `earlyoom`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    finit.services.earlyoom = {
      description = "early oom daemon";
      command = "${cfg.package}/bin/earlyoom --syslog -r 3600";
    };
  };
}
