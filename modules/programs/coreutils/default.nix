{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.coreutils;
in
{
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

  config = {
    environment.systemPackages = [ cfg.package ];

    system.activation.scripts.usrbinenv = ''
      mkdir -p -m 0755 /usr/bin

      # required /usr/bin/env symlink
      ln -sfn ${lib.getExe' cfg.package "env"} /usr/bin/env
    '';
  };
}
