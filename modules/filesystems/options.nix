{ lib, ... }:
let
  specialFSTypes = [
    "proc"
    "sysfs"
    "tmpfs"
    "ramfs"
    "devtmpfs"
    "devpts"
  ];

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

  addCheckDesc =
    desc: elemType: check:
    lib.types.addCheck elemType check
    // {
      description = "${elemType.description} (with check: ${desc})";
    };

  nonEmptyWithoutTrailingSlash = addCheckDesc "non-empty without trailing slash" lib.types.str (
    s: (builtins.match "[ \t\n]*" s) == null && (builtins.match ".+/" s) == null
  );

  fileSystemOpts =
    { name, config, ... }:
    {

      options = {
        mountPoint = lib.mkOption {
          example = "/mnt/usb";
          type = nonEmptyWithoutTrailingSlash;
          description = "Location of the mounted file system.";
        };

        device = lib.mkOption {
          default = null;
          example = "/dev/sda";
          type = with lib.types; nullOr nonEmptyStr;
          description = "Location of the device.";
        };

        fsType = lib.mkOption {
          default = "auto";
          example = "ext3";
          type = lib.types.nonEmptyStr;
          description = "Type of the file system.";
        };

        label = lib.mkOption {
          default = null;
          example = "root-partition";
          type = with lib.types; nullOr nonEmptyStr;
          description = "Label of the device (if any).";
        };

        noCheck = lib.mkOption {
          default = false;
          type = lib.types.bool;
          description = "Disable running fsck on this filesystem.";
        };

        options = lib.mkOption {
          default = [ "defaults" ];
          example = [ "data=journal" ];
          description = "Options used to mount the file system.";
          type = with lib.types; nonEmptyListOf nonEmptyStr;
        };

        depends = lib.mkOption {
          default = [ ];
          example = [ "/persist" ];
          type = lib.types.listOf nonEmptyWithoutTrailingSlash;
          description = ''
            List of paths that should be mounted before this one. This filesystem's
            {option}`device` and {option}`mountPoint` are always
            checked and do not need to be included explicitly. If a path is added
            to this list, any other filesystem whose mount point is a parent of
            the path will be mounted before this filesystem. The paths do not need
            to actually be the {option}`mountPoint` of some other filesystem.
          '';
        };

        neededForBoot = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Whether this filesystem is needed for boot. If set, the filesystem
            will be mounted in the initial ramdisk.
          '';
        };
      };

      config = {
        mountPoint = lib.mkDefault name;
        device = lib.mkIf (lib.elem config.fsType specialFSTypes) (lib.mkDefault config.fsType);
        neededForBoot = lib.mkIf (lib.elem config.mountPoint pathsNeededForBoot) (lib.mkForce true);
      };

    };
in
{
  options = {
    fileSystems = lib.mkOption {
      type = with lib.types; attrsOf (submodule fileSystemOpts);
      default = { };
      example = lib.literalExpression ''
        {
          "/".device = "/dev/hda1";
          "/data" = {
            device = "/dev/hda2";
            fsType = "ext3";
            options = [ "data=journal" ];
          };
          "/bigdisk".label = "bigdisk";
        }
      '';
      description = ''
        The file systems to be mounted.  It must include an entry for
        the root directory (`mountPoint = "/"`).  Each
        entry in the list is an attribute set with the following fields:
        `mountPoint`, `device`,
        `fsType` (a file system type recognised by
        {command}`mount`; defaults to
        `"auto"`), and `options`
        (the mount options passed to {command}`mount` using the
        {option}`-o` flag; defaults to `[ "defaults" ]`).

        Instead of specifying `device`, you can also
        specify a volume label (`label`) for file
        systems that support it, such as ext2/ext3 (see {command}`mke2fs -L`).
      '';
    };
  };
}
