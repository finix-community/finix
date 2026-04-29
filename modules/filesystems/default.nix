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

  makeSwapEntry =
    sw:
    let
      device = if sw.label != null then "/dev/disk/by-label/${sw.label}" else sw.device;
      options = sw.options ++ lib.optional (sw.priority != null) "pri=${toString sw.priority}";
    in
    "${escape device} none swap ${escape (lib.concatStringsSep "," options)} 0 0\n";

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
        "ntfs3"
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
    ./fuse.mergerfs.nix
    ./fuse.nix
    ./luks.nix
    ./lvm.nix
    ./ntfs3.nix
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

    environment.systemPackages = lib.unique (
      lib.flatten (
        lib.concatMap (v: lib.optional v.enable v.packages or [ ]) (
          lib.attrValues config.boot.supportedFilesystems
        )
      )
    );

    environment.etc.fstab.text = ''
      # This is a generated file.  Do not edit!
      #
      # To make changes, edit the fileSystems and swapDevices NixOS options
      # in your /etc/nixos/configuration.nix file.
      #
      # <file system> <mount point>   <type>  <options>       <dump>  <pass>

      # filesystems
      ${makeFstabEntries (lib.filter (fs: !lib.elem fs.fsType [ "luks" "lvm" ]) fileSystems) { }}

      # swap devices
      ${lib.concatMapStrings makeSwapEntry config.swapDevices}
    '';

    boot.supportedFilesystems = lib.mapAttrs' (
      _: v: lib.nameValuePair v.fsType { enable = true; }
    ) config.fileSystems;
  };
}
