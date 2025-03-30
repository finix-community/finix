{ pkgs, ... }:
{
  imports = [
    (pkgs.path + "/nixos/modules/misc/assertions.nix")
    (pkgs.path + "/nixos/modules/misc/ids.nix")
    (pkgs.path + "/nixos/modules/misc/meta.nix")
  ];
}
