{
  config,
  pkgs,
  lib,
  pkgs,
  utils,
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
      options =
        sw.options
        ++ lib.optional (sw.priority != null) "pri=${toString sw.priority}"
        ++ lib.optional (sw.discardPolicy != null) (
          if sw.discardPolicy == "both" then "discard" else "discard=${sw.discardPolicy}"
        );
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

  # Swap entries with randomEncryption.enable can't be stable fstab lines: the backing device is a fresh /dev/mapper/<name> created with a brand new random key on every boot, so they're set up imperatively instead
  isEncryptedSwap = sw: sw.randomEncryption.enable;
  plainSwapDevices = lib.filter (sw: !isEncryptedSwap sw) config.swapDevices;
  encryptedSwapDevices = lib.filter isEncryptedSwap config.swapDevices;

  sanitizeName = s: lib.replaceStrings [ "/" " " ] [ "-" "-" ] (lib.removePrefix "/" s);

  makeEncryptedSwapTask =
    sw:
    let
      name = "cryptswap-${sanitizeName sw.device}";
    in
    {
      inherit name;
      value =
        let
          re = sw.randomEncryption;
          options =
            sw.options
            ++ lib.optional (sw.priority != null) "pri=${toString sw.priority}"
            ++ lib.optional (sw.discardPolicy != null) (
              if sw.discardPolicy == "both" then "discard" else "discard=${sw.discardPolicy}"
            );
        in
        {
          description = "Encrypted swap device on ${sw.device}";
          runlevels = "S";
          command = toString (
            pkgs.writeShellScript name ''
              set -eu
              ${pkgs.cryptsetup}/bin/cryptsetup plainOpen \
                -c ${lib.escapeShellArg re.cipher} \
                -s ${toString re.keySize} \
                ${lib.optionalString (re.sectorSize != 0) "--sector-size ${toString re.sectorSize}"} \
                ${lib.optionalString re.allowDiscards "--allow-discards"} \
                -d ${lib.escapeShellArg re.source} \
                ${lib.escapeShellArg sw.device} ${lib.escapeShellArg name}
              ${pkgs.util-linuxMinimal}/bin/mkswap /dev/mapper/${name}
              ${pkgs.util-linuxMinimal}/bin/swapon -o ${lib.escapeShellArg (lib.concatStringsSep "," options)} /dev/mapper/${name}
            ''
          );
        };
    };
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

    assertions = lib.map (sw: {
      assertion = sw.label == null && (builtins.match "/dev/disk/by-(uuid|label)/.*" sw.device == null);
      message = ''
        Random-encrypted swap device ${sw.device} must not use swapDevices.*.label,
        and should not be referenced by UUID or label, since those are erased and regenerated on every
        boot once the partition is encrypted. Use a stable path such as
        /dev/disk/by-partuuid/... instead.
      '';
    }) encryptedSwapDevices;

    environment.systemPackages =
      lib.unique (
        lib.flatten (
          lib.concatMap (v: lib.optional v.enable v.packages or [ ]) (
            lib.attrValues config.boot.supportedFilesystems
          )
        )
      )
      ++ lib.optional (encryptedSwapDevices != [ ]) pkgs.cryptsetup;

    finit.tasks = lib.listToAttrs (lib.map makeEncryptedSwapTask encryptedSwapDevices);

    environment.etc.fstab.text = ''
      # This is a generated file.  Do not edit!
      #
      # To make changes, edit the fileSystems and swapDevices NixOS options
      # in your /etc/nixos/configuration.nix file.
      #
      # <file system> <mount point>   <type>  <options>       <dump>  <pass>

      # filesystems
      ${makeFstabEntries (lib.filter (
        fs:
        !lib.elem fs.fsType [
          "luks"
          "lvm"
        ]
      ) fileSystems) { }}

      # swap devices (random-encrypted swap is handled by finit.tasks instead)
      ${lib.concatMapStrings makeSwapEntry plainSwapDevices}
    '';

    boot.supportedFilesystems = lib.mapAttrs' (
      _: v: lib.nameValuePair v.fsType { enable = true; }
    ) config.fileSystems;
  };
}
