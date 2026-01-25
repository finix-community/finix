{
  config,
  lib,
  pkgs,
  nodes,
  ...
}:

let
  cfg = config.testing;

  # get sorted node names for consistent ordering
  nodeNames = lib.sort lib.lessThan (lib.attrNames nodes);

  # find this node's index (1-based for ip addressing)
  nodeIndex = (lib.lists.findFirstIndex (name: name == config.networking.hostName) 0 nodeNames) + 1;

  # generate a deterministic mac address using nixos convention
  # format: 52:54:00:12:${vlan}:${node} where vlan is 01 (fixed) and node is the node index
  # this matches the nixos testing framework for compatibility
  nodeMac =
    let
      zeroPad = n: if n < 16 then "0${lib.toHexString n}" else lib.toHexString n;
      vlan = 1;
    in
    "52:54:00:12:${zeroPad vlan}:${zeroPad nodeIndex}";

  # this node's ip address
  nodeIp = "192.168.1.${toString nodeIndex}";

  vlan = 1;
in
{
  imports = [
    ./backdoor.nix
  ];

  options = {
    testing.enable = lib.mkEnableOption "test instrumentation";

    testing.enableRootDisk = lib.mkEnableOption "use a root file-system on a disk image otherwise use tmpfs";

    testing.driver = lib.mkOption {
      type = lib.types.enum [ "tcl" ];
      description = "Test driver.";
    };

    testing.graphics.enable = lib.mkEnableOption "graphic devices";

    testing.network = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable test network interface.";
      };

      ip = lib.mkOption {
        type = lib.types.str;
        default = nodeIp;
        description = "IP address for this node on the test network.";
        readOnly = true;
      };

      mac = lib.mkOption {
        type = lib.types.str;
        default = nodeMac;
        description = "MAC address for this node.";
        readOnly = true;
      };

      nodeIndex = lib.mkOption {
        type = lib.types.int;
        default = nodeIndex;
        description = "This node's index in the test network (1-based).";
        readOnly = true;
      };

      vlan = lib.mkOption {
        type = lib.types.int;
        default = vlan;
        description = "VLAN number for this test network.";
        readOnly = true;
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.sysklogd.enable = true;

    environment.etc."syslog.conf".source = pkgs.writeText "syslog.conf" ''
      # log *all* messages to console so they're visible in tests
      *.* /dev/console

      include /etc/syslog.d/*.conf
    '';

    # add /etc/hosts entries for all test nodes
    networking.hosts = lib.listToAttrs (
      lib.imap1 (idx: name: {
        name = "192.168.1.${toString idx}";
        value = [ name ];
      }) nodeNames
    );

    virtualisation.qemu.extraArgs = lib.optional (!cfg.graphics.enable) "-nographic";

    programs.ifupdown-ng.enable = true;
    programs.ifupdown-ng.auto = [ "eth0" ];
    programs.ifupdown-ng.iface.eth0 = {
      address = "${nodeIp}/24";
    };
  };
}
