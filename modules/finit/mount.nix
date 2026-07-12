{
  config,
  lib,
  utils,
  ...
}:
let
  cfg = config.boot.initrd;

  isBind = fs: lib.elem "bind" fs.options;
  isZfs = fs: fs.fsType == "zfs";
  isSpecial =
    fs:
    lib.elem fs.fsType [
      "proc"
      "sysfs"
      "tmpfs"
      "ramfs"
      "devtmpfs"
      "devpts"
    ];
  isPseudo =
    fs:
    lib.elem fs.fsType [
      "luks"
      "lvm"
    ];

  needsWaitDev =
    fs:
    !(isBind fs) && !(isSpecial fs) && !(isZfs fs) && fs.device != null && lib.hasPrefix "/" fs.device;

  poolOf = fs: lib.head (lib.splitString "/" fs.device);

  # "/nix" precedes "/nix/store" but not "/nixos"; "/" precedes everything
  pathIsPrefix = a: b: a == b || a == "/" || lib.hasPrefix (a + "/") b;

  mountable = lib.filter (fs: fs.neededForBoot && !(isPseudo fs)) (lib.attrValues config.fileSystems);

  # a bind mount's source must be mounted before the bind itself
  parentPaths = fs: fs.depends ++ lib.optional (isBind fs) fs.device;

  parentConditions =
    fs:
    let
      isParent =
        p:
        p.mountPoint != fs.mountPoint
        && (
          pathIsPrefix p.mountPoint fs.mountPoint || lib.any (pathIsPrefix p.mountPoint) (parentPaths fs)
        );
    in
    map (p: "task/mount-${utils.escapePath p.mountPoint}/success") (lib.filter isParent mountable);

  readinessConditions =
    fs:
    if isZfs fs then
      [ "task/zpool-import-${utils.escapePath (poolOf fs)}/success" ]
    else if needsWaitDev fs then
      [ "task/wait-dev-${utils.escapePath fs.mountPoint}/success" ]
    else
      [ ];

  deviceConditions =
    lib.optionals config.services.mdevd.enable [ "run/coldplug/success" ]
    ++ lib.optionals config.services.gardendevd.enable [ "run/gardendevctl:2/success" ]
    ++ lib.optionals config.services.udev.enable [ "run/udevadm:5/success" ]
    ++ lib.optionals config.services.keventd.enable [ "service/keventd/ready" ];

  names = map (fs: utils.escapePath fs.mountPoint) mountable;
in
{
  config = {
    boot.initrd.finit.tasks = lib.mkMerge [
      (lib.genAttrs' (lib.filter needsWaitDev mountable) (
        fs:
        lib.nameValuePair "wait-dev-${utils.escapePath fs.mountPoint}" {
          conditions = deviceConditions;
          script = ''
            # 90s total timeout, polled every 0.1s (busybox sleep supports fractional)
            tries=900
            i=0
            while [ "$i" -lt "$tries" ]; do
              if [ -e "${fs.device}" ]; then
                exit 0
              fi
              i=$((i + 1))
              sleep 0.1
            done

            printf 'finix-wait-dev: %s did not appear after 90s\n' "${fs.device}" >&2
            exit 1
          '';
        }
      ))
      (lib.genAttrs' mountable (
        fs:
        lib.nameValuePair "mount-${utils.escapePath fs.mountPoint}" {
          conditions = readinessConditions fs ++ parentConditions fs;
          command =
            let
              targetRoot = "/sysroot";
              opts = lib.concatStringsSep "," (fs.options ++ [ "X-mount.mkdir" ]);
            in
            if isBind fs then
              "mount -o ${opts} ${targetRoot}${fs.device} ${targetRoot}${fs.mountPoint}"
            else
              "mount -t ${fs.fsType} -o ${opts} ${fs.device} ${targetRoot}${fs.mountPoint}";
        }
      ))
      (lib.mkIf (cfg.fileSystemImportCommands != "") {
        fs-import = {
          conditions = deviceConditions;
          tty = "@console";
          script = cfg.fileSystemImportCommands;
        };
      })
    ];

    assertions = [
      {
        assertion = lib.length names == lib.length (lib.unique names);
        message = "boot.initrd: neededForBoot filesystems collide after escaping to finit stanza names";
      }
    ];
  };
}
