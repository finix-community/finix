# provides compatibility options so a finix system can be built with `nixos-rebuild`
{
  config,
  pkgs,
  lib,
  ...
}:
{
  options.system.build = {
    nixos-rebuild = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nixos-rebuild-ng;
      internal = true;
    };

    toplevel = lib.mkOption {
      type = lib.types.anything;
      default = config.system.topLevel;
      internal = true;
    };
  };

  config = {
    environment.systemPackages = [
      # nixos-enter and nixos-install depend on a systemd-tmpfiles implementation
      # see https://github.com/NixOS/nixpkgs/blob/80bdc1e5ce51f56b19791b52b2901187931f5353/pkgs/by-name/ni/nixos-enter/nixos-enter.sh#L108 for details
      (lib.lowPrio (
        pkgs.writeShellScriptBin "systemd-tmpfiles" ''
          exec "${config.finit.package}/libexec/finit/tmpfiles" "$@"
        ''
      ))
    ];
  };
}
