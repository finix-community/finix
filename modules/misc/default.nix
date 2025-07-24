{ pkgs, ... }:
{
  imports = [
    ./assertions.nix
    (pkgs.path + "/nixos/modules/misc/ids.nix")
    (pkgs.path + "/nixos/modules/misc/meta.nix")
  ];
}
