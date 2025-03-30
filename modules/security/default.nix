{ pkgs, ... }:
{
  imports = [
    ./pam
    ./shadow
    ./sudo
    ./wrappers

    (pkgs.path + "/nixos/modules/security/ca.nix")
  ];
}
