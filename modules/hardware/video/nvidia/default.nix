{ config, lib, ... }:
let
  cfg = config.hardware.nvidia;
in
{
  imports = [
    ./options.nix
    ./assertions.nix
    ./kernel.nix
    ./packages.nix
    ./power-management.nix
    ./prime.nix
  ];

  config = lib.mkMerge [
    (lib.mkIf (cfg.open != null) {
      hardware.nvidia.kernelModule = if cfg.open then "open" else "closed";
    })
  ];
}