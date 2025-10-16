{ modulesPath, ... }:
{
  imports = [
    ./fontconfig.nix

    "${modulesPath}/config/fonts/packages.nix"
  ];
}
