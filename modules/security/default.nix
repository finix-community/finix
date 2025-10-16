{ modulesPath, ... }:
{
  imports = [
    ./pam
    ./shadow
    ./sudo
    ./wrappers

    "${modulesPath}/security/ca.nix"
  ];
}
