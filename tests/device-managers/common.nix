# Shared device-manager VM test factory
{
  backend,
  extraNodeConfig ? { },
}:
let
  inherit (backend) name serviceName readyCondition coldplugCondition module disks eventScript;
  configCheck = backend.configCheck or "";
  configServiceName = backend.configServiceName or serviceName;
  configBinary = backend.configBinary or serviceName;
  reloadCommand = backend.reloadCommand or "initctl reload ${serviceName}";
  coldplugEvents = backend.coldplugEvents or true;
  diskAt = name: builtins.getAttr name disks.cold;
  coldDiskOrder = builtins.filter (name: name != "gptExt4") disks.order;
  hotDiskOrder = disks.order;
  coldDisks = builtins.listToAttrs (
    builtins.map (name: {
      inherit name;
      value = diskAt name;
    }) coldDiskOrder
  );
  hotDisks = disks.hot;
  metadata = disk: disk // { image = toString disk.image; };
  deviceManagerModule =
    { config, lib, pkgs, ... }:
    {
      imports = [ (module { inherit eventScript; }) ];

      services.getty.enable = true;

      boot.supportedFilesystems = {
        ext4.enable = true;
        btrfs.enable = true;
        vfat.enable = true;
      };

      environment.systemPackages = with pkgs; [
        btrfs-progs
        dosfstools
        e2fsprogs
        util-linux
      ];

      finit.tmpfiles.rules = [
        "d /run/device-manager-test 0755 root root -"
      ];

      virtualisation.qemu.extraArgs = lib.concatMap (name: let
        disk = diskAt name;
      in [
        "-drive"
        "if=none,id=${disk.serial},format=raw,readonly=on,file=${disk.image}"
        "-device"
        "virtio-blk-pci,drive=${disk.serial},id=${disk.serial},serial=${disk.serial}"
      ]) coldDiskOrder;

      assertions = [
        {
          assertion = config.services.${configServiceName}.enable;
          message = "device-manager test backend '${name}' must enable ${configServiceName}";
        }
        {
          assertion = lib.all (
            service: service == configServiceName || !config.services.${service}.enable
          ) [
            "mdevd"
            "udev"
            "keventd"
            "gardendevd"
          ];
          message = "device-manager test must run exactly one device manager";
        }
      ];
    };

  testScript =
    { nodes }:
    let
      managerService = builtins.getAttr configServiceName nodes.machine.config.services;
      managerHasPackage = builtins.hasAttr "package" managerService;
      managerPackage =
        if managerHasPackage then
          toString managerService.package
        else
          toString nodes.machine.config.finit.package;
      configCommand =
        backend.configCommand
        or (
          if managerHasPackage then
            "${managerPackage}/bin/${configBinary} ${configCheck}"
          else
            "${managerPackage}/libexec/finit/${configBinary} ${configCheck}"
        );
      diskGid = toString nodes.machine.config.ids.gids.disk;
      jsonMetadata = set:
        builtins.replaceStrings [ "null" "true" "false" ] [ "None" "True" "False" ] (
          builtins.toJSON (builtins.mapAttrs (_: metadata) set)
        );
    in
    ''
      import datetime as dt
      import json
      ${builtins.readFile ./disk/helpers.py}
      ${builtins.readFile ./disk/qemu.py}
      ${builtins.readFile ./disk/scenarios.py}
      ${backend.backendScript}

      DISK_GID = ${diskGid}
      CONFIG_CHECK = ${builtins.toJSON configCommand}
      RELOAD_COMMAND = ${builtins.toJSON reloadCommand}
      EVENT_LOG = "/run/device-manager-test/events"
      COLD_DISKS = ${jsonMetadata coldDisks}
      COLD_ORDER = ${builtins.toJSON coldDiskOrder}
      HOT_DISKS = ${jsonMetadata hotDisks}
      HOT_ORDER = ${builtins.toJSON hotDiskOrder}
      COLDPLUG = ${if coldplugEvents then "True" else "False"}
      TEST_TIMEOUT = dt.timedelta(seconds=30)

      def service_status(name):
          return json.loads(machine.succeed(f"initctl -j status {name}"))


      machine.start()
      machine.wait_for_console_text("finix - stage 1", timeout=dt.timedelta(minutes=3))
      machine.wait_for_console_text("finix - stage 2", timeout=dt.timedelta(minutes=3))
      machine.wait_for_console_text("entering runlevel 2", timeout=dt.timedelta(minutes=3))

      with subtest("device-manager startup and readiness"):
          machine.wait_until_succeeds(
              "test -e /run/finit/cond/${readyCondition}", timeout=TEST_TIMEOUT
          )
          machine.wait_until_succeeds(
              "test -e /run/finit/cond/${coldplugCondition}", timeout=TEST_TIMEOUT
          )
          manager = service_status("${serviceName}")
          assert manager["status"] == "running", manager
          assert manager["pid"] > 1, manager
          backend_validate(machine)

      with subtest("coldplug filesystem identities"):
          coldplug_filesystems(
              machine,
              COLD_DISKS,
              COLD_ORDER,
              EVENT_LOG,
              backend_add_check,
              TEST_TIMEOUT,
          )
      COLDPLUG = False

      with subtest("device-manager isolation"):
          for service in ("mdevd", "udevd", "keventd", "gardendevd"):
              if service == "${serviceName}":
                  continue
              machine.succeed(f"test ! -e /run/finit/cond/service/{service}/ready")
          machine.succeed("kill -0 1")

      with subtest("reload keeps the daemon alive"):
          before = service_status("${serviceName}")
          machine.succeed(RELOAD_COMMAND)
          machine.wait_until_succeeds(
              "test -e /run/finit/cond/${readyCondition}", timeout=TEST_TIMEOUT
          )
          after = service_status("${serviceName}")
          assert after["status"] == "running", after
          assert after["pid"] == before["pid"], (before, after)
          backend_validate(machine)

      with subtest("dynamic filesystem hotplug"):
          hotplug_filesystems(
              machine,
              HOT_DISKS,
              HOT_ORDER,
              EVENT_LOG,
              backend_add_check,
              backend_remove_check,
              TEST_TIMEOUT,
          )

      with subtest("shutdown"):
          machine.shutdown()
    '';
in
{
  name = "device-managers.${name}";
  nodes.machine = {
    imports = [
      deviceManagerModule
      extraNodeConfig
    ];
  };
  inherit testScript;
}
