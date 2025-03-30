{ pkgs, ... }:
{
  imports = [
    ./portal.nix

    (pkgs.path + "/nixos/modules/config/xdg/autostart.nix")
    (pkgs.path + "/nixos/modules/config/xdg/mime.nix")
    (pkgs.path + "/nixos/modules/config/xdg/terminal-exec.nix")
  ];
}
