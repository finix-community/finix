{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.sysklogd;
in
{
  imports = [
    ./sysklogd-dinit.nix
    ./sysklogd-finit.nix
  ];

  options.services.sysklogd = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [sysklogd](${pkgs.sysklogd.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.sysklogd;
      defaultText = lib.literalExpression "pkgs.sysklogd";
      description = ''
        The package to use for `sysklogd`.
      '';
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Additional `sysklogd` configuration. See {manpage}`syslog.conf(5)`
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc."syslog.d/nixos.conf".text = cfg.extraConfig;
    environment.etc."syslog.conf".source =
      lib.mkDefault "${cfg.package}/share/doc/sysklogd/syslog.conf";

  };
}
