{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.sh;
  userShell = "${cfg.defaultUserShell}${cfg.defaultUserShell.shellPath}";
in
{
  options.programs.sh = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable shell configuration.
      '';
    };

    defaultUserShell = lib.mkOption {
      type = lib.types.shellPackage;
      default = pkgs.bashInteractive;
      defaultText = lib.literalExpression "pkgs.bashInteractive";
      example = lib.literalExpression "pkgs.fish";
      description = ''
        The shell package assigned to user accounts created with
        {option} `isNormalUser = true`.
      '';
    };

    environmentShell = lib.mkOption {
      type = lib.types.shellPackage;
      default = pkgs.dash;
      defaultText = lib.literalExpression "pkgs.dash";
      example = lib.literalExpression "pkgs.busybox";
      description = ''
        Default shell linked system-wide to /bin/sh. Any modifications 
        are recommended to be POSIX-compliant.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.defaultUserShell ];
    environment.shells = [
      "/run/current-system/sw${cfg.defaultUserShell.shellPath}"
      userShell
    ];
  };
}
