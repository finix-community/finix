{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.ash;

  ash =
    (pkgs.writeScriptBin "ash" ''
      #!${lib.getExe' pkgs.busybox "ash"}
      ${lib.getExe' pkgs.busybox "ash"} "$@"
    '').overrideAttrs
      (old: {
        passthru = (old.passtru or { }) // {
          shellPath = "/bin/ash";
        };
      });
in
{
  options.programs.ash = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable ash as a system shell.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = ash;
      defaultText = lib.literalExpression "ash";
      description = ''
        The package to use for `ash`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    environment.shells = [
      "/run/current-system/sw${cfg.package.shellPath}"
      "${cfg.package}${cfg.package.shellPath}"
    ];
  };
}
