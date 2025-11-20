{ modulesPath, ... }:
{
  imports = [
    ./pam
    ./wrappers

    "${modulesPath}/security/ca.nix"
  ];
}
