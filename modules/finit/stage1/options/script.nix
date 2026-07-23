{ lib, pkgs }:
{ name, config, ... }:
{
  options.script = lib.mkOption {
    type = lib.types.lines;
    default = "";
    description = ''
      Shell commands executed as the main process.
    '';
  };

  config = lib.mkIf (config.script != "") {
    command = lib.mkForce (
      pkgs.writeScript (lib.replaceStrings [ "@" ] [ "_" ] name) ''
        #!/bin/sh
        set -eu
        ${config.script}
      ''
    );
  };
}
