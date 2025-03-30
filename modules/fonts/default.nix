{ pkgs, ... }:
{
  imports = [
    ./fontconfig.nix

    (pkgs.path + "/nixos/modules/config/fonts/packages.nix")
  ];
}
