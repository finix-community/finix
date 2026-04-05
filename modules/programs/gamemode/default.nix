{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.gamemode;
  format = pkgs.formats.ini { listsAsDuplicateKeys = true; };
in
{
  options.programs.gamemode = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [gamemode](${pkgs.gamemode.meta.homepage}).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.gamemode;
      defaultText = lib.literalExpression "pkgs.gamemode";
      description = ''
        The package to use for `gamemode`.
      '';
    };

    settings = lib.mkOption {
      type = format.type;
      default = { };
      description = ''
        `gamemode` configuration. See {manpage}`gamemoded(8)`
        for additional details.
      '';
      example = lib.literalExpression ''
        {
          general = {
            renice = 10;
          };

          # Warning: GPU optimisations have the potential to damage hardware
          gpu = {
            apply_gpu_optimisations = "accept-responsibility";
            gpu_device = 0;
            amd_performance_level = "high";
          };

          custom = {
            start = "''${pkgs.libnotify}/bin/notify-send 'GameMode started'";
            end = "''${pkgs.libnotify}/bin/notify-send 'GameMode ended'";
          };
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    environment.etc."gamemode.ini".source = format.generate "gamemode.ini" cfg.settings;
    environment.etc."security/limits.d/10-gamemode.conf".source =
      "${cfg.package}/etc/security/limits.d/10-gamemode.conf";

    security.wrappers.gamemoded = {
      owner = "root";
      group = "root";
      source = "${cfg.package}/bin/gamemoded";
      capabilities = "cap_sys_nice+ep";
    };

    users.groups.gamemode = { };
  };
}
