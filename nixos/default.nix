# compatibility layer for build a finix system with nix channels
#
# NIX_PATH should include at least:
# - `nixpkgs` and `finix` channels,
# - `nixos-config` pointing to your configuration.nix file
# - `nixos-system` pointing to the `./nixos` subdirectory of the `finix` channel
#
# for example, assuming you have a `nixpkgs` and `finix` channel under /nix/var/nix/profiles/per-user/root/channels:
# NIX_PATH=nixos-config=/etc/nixos/configuration.nix:nixos-system=/nix/var/nix/profiles/per-user/root/channels/finix/nixos:/nix/var/nix/profiles/per-user/root/channels

{ ... }:
let
  pkgs = import <nixpkgs> { };
  lib = import <nixpkgs/lib>;

  nixosModules = import ../modules;
  configuration = <nixos-config>;

  eval = lib.evalModules {
    modules = [
      configuration
      nixosModules.default
      { nixpkgs.pkgs = lib.mkDefault pkgs; }
    ];
  };
in
{
  inherit (eval) config;
}
