{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [ ./test.nix ];

  options.programs.coreutils.package = lib.mkOption {
    type = lib.types.package;
    default = pkgs.coreutils;
    defaultText = lib.literalExpression "pkgs.coreutils";
    example = lib.literalExpression "pkgs.busybox";
    description = ''
      Package providing the standard core utilities used by the system.

      Most modules should use this option instead of depending directly on
      `pkgs.coreutils`, allowing alternative implementations such as 
      `uutils`, `busybox`, or `toybox` to be selected globally.
    '';
  };

  config.environment.systemPackages = [ config.programs.coreutils.package ];
}
