{ modulesPath, ... }:
{
  imports = [
    ./pam
    ./shadow
    ./wrappers

    "${modulesPath}/security/ca.nix"
  ];
}
