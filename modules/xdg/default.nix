{ modulesPath, ... }:
{
  imports = [
    ./portal.nix

    "${modulesPath}/config/xdg/autostart.nix"
    "${modulesPath}/config/xdg/mime.nix"
    "${modulesPath}/config/xdg/terminal-exec.nix"
  ];
}
