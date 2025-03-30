{ config, lib, ... }:
let
  # Check whenever fileSystem is needed for boot.  NOTE: Make sure
  # pathsNeededForBoot is closed under the parent relationship, i.e. if /a/b/c
  # is in the list, put /a and /a/b in as well.
  pathsNeededForBoot = [
    "/"
    "/etc"
    "/nix"
    "/nix/store"
    "/usr"
    "/var"
    "/var/lib"
    "/var/log"
  ];

  fsNeededForBoot = fs: fs.neededForBoot || lib.elem fs.mountPoint pathsNeededForBoot;
in
{
  config = {
    boot.initrd.supportedFilesystems = config.fileSystems
      |> lib.filterAttrs (_: fsNeededForBoot)
      |> lib.mapAttrs' (_: v: lib.nameValuePair v.fsType { enable = true; })
    ;
  };
}
