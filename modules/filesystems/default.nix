{
  config,
  pkgs,
  lib,
  ...
}:
let
  utils = import (pkgs.path + "/nixos/lib/utils.nix") { inherit config pkgs lib; };

  # https://wiki.archlinux.org/index.php/fstab#Filepath_spaces
  escape = string: lib.replaceStrings [ " " "\t" ] [ "\\040" "\\011" ] string;

  fileSystems' = lib.toposort utils.fsBefore (lib.attrValues config.fileSystems);

  fileSystems =
    if fileSystems' ? result then
      # use topologically sorted fileSystems everywhere
      fileSystems'.result
    else
      # the assertion below will catch this,
      # but we fall back to the original order
      # anyway so that other modules could check
      # their assertions too
      (lib.attrValues config.fileSystems);

  makeFstabEntries =
    let
      fsToSkipCheck = [
        "none"
        "auto"
        "overlay"
        "iso9660"
        "bindfs"
        "udf"
        "btrfs"
        "zfs"
        "tmpfs"
        "bcachefs"
        "nfs"
        "nfs4"
        "nilfs2"
        "vboxsf"
        "squashfs"
        "glusterfs"
        "apfs"
        "9p"
        "cifs"
        "prl_fs"
        "vmhgfs"
      ]
      ++
        lib.optionals false # (!config.boot.initrd.checkJournalingFS)
          [
            "ext3"
            "ext4"
            "reiserfs"
            "xfs"
            "jfs"
            "f2fs"
          ];
      isBindMount = fs: lib.elem "bind" fs.options;
      skipCheck =
        fs: fs.noCheck || fs.device == "none" || lib.elem fs.fsType fsToSkipCheck || isBindMount fs;
    in
    fstabFileSystems:
    { }:
    lib.concatMapStrings (
      fs:
      (
        if fs.device != null then
          escape fs.device
        else
          throw "No device specified for mount point ‘${fs.mountPoint}’."
      )
      + " "
      + escape fs.mountPoint
      + " "
      + fs.fsType
      + " "
      + escape (lib.concatStringsSep "," fs.options)
      + " 0 "
      + (
        if skipCheck fs then
          "0"
        else if fs.mountPoint == "/" then
          "1"
        else
          "2"
      )
      + "\n"
    ) fstabFileSystems;
in
{
  imports = [
    ./options.nix

    ./9p.nix
    ./btrfs.nix
    ./efivarfs.nix
    ./ext2.nix
    ./ext4.nix
    ./f2fs.nix
    ./fuse.nix
    ./special.nix
    ./tmpfs.nix
    ./vfat.nix
    ./xfs.nix
    ./zfs.nix
  ];

  config = {
    # Add the mount helpers to the system path so that `mount' can find them.
    # system.fsPackages = [ pkgs.dosfstools ];
    # environment.systemPackages = with pkgs; [ fuse3 fuse ] ++ config.system.fsPackages;

    environment.systemPackages =
      config.boot.supportedFilesystems
      |> lib.filterAttrs (_: v: v.enable)
      |> lib.attrValues
      |> lib.catAttrs "packages"
      |> lib.flatten
      |> lib.unique;

    environment.etc.fstab.text = ''
      # This is a generated file.  Do not edit!
      #
      # To make changes, edit the fileSystems and swapDevices NixOS options
      # in your /etc/nixos/configuration.nix file.
      #
      # <file system> <mount point>   <type>  <options>       <dump>  <pass>

      # filesystems
      ${makeFstabEntries fileSystems { }}

      # TODO: swap devices
    '';

    boot.supportedFilesystems = lib.mapAttrs' (
      _: v: lib.nameValuePair v.fsType { enable = true; }
    ) config.fileSystems;
  };
}
