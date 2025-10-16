{ modulesPath, ... }:
{
  imports = [
    ./assertions.nix

    "${modulesPath}/misc/ids.nix"
    "${modulesPath}/misc/meta.nix"
  ];
}
