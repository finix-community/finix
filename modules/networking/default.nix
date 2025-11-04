{ config, pkgs, lib, ... }:
let
  cfg = config.networking;

  hostidFile = pkgs.runCommand "gen-hostid" { preferLocalBuild = true; } ''
    hi="${cfg.hostId}"
    ${
      if pkgs.stdenv.hostPlatform.isBigEndian then
        ''
          echo -ne "\x''${hi:0:2}\x''${hi:2:2}\x''${hi:4:2}\x''${hi:6:2}" > $out
        ''
      else
        ''
          echo -ne "\x''${hi:6:2}\x''${hi:4:2}\x''${hi:2:2}\x''${hi:0:2}" > $out
        ''
    }
  '';
in
{
  options.networking = {
    hostName = lib.mkOption {
      type = lib.types.str;
      default = "finix";
    };

    hostId = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      example = "4e98920d";
      description = ''
        The 32-bit host ID of the machine, formatted as 8 hexadecimal characters.

        You should try to make this ID unique among your machines. You can
        generate a random 32-bit ID using the following commands:

        `head -c 8 /etc/machine-id`

        (this derives it from the machine-id that systemd generates) or

        `head -c4 /dev/urandom | od -A none -t x4`

        The primary use case is to ensure when using ZFS that a pool isn't imported
        accidentally on a wrong machine.
      '';
    };

    hosts = lib.mkOption {
      type = with lib.types; attrsOf (listOf str);
      example = lib.literalExpression ''
        {
          "127.0.0.1" = [ "foo.bar.baz" ];
          "192.168.0.2" = [ "fileserver.local" "nameserver.local" ];
        };
      '';
      description = ''
        Locally defined maps of hostnames to IP addresses.
      '';
    };
  };

  config = {
    assertions =
      let
        hexChars = lib.stringToCharacters "0123456789abcdef";
        isHexString = s: lib.all (c: lib.elem c hexChars) (lib.stringToCharacters (lib.toLower s));
      in
        [
          { assertion = cfg.hostId == null || (lib.stringLength cfg.hostId == 8 && isHexString cfg.hostId);
            message = "Invalid value given to the networking.hostId option.";
          }
        ];

    boot.kernel.sysctl = {
      # allow all users to do ICMP echo requests (ping)
      "net.ipv4.ping_group_range" = lib.mkDefault "0 2147483647";

      # Generate link-local addresses.
      "net.ipv6.conf.all.addr_gen_mode" = lib.mkDefault 3;
    };

    networking.hosts = {
      localhost = [ "127.0.0.1" ];
      ${config.networking.hostName} = [ "127.0.0.2" ];
    };

    boot.initrd = {
      contents = lib.optionals (cfg.hostId != null) [
        { target = "/etc/hostid"; source = hostidFile; }
      ];
    };

    environment.etc = {
      hostname.text = cfg.hostName + "\n";

      hosts.text =
        let
          oneToString = set: ip: ip + " " + lib.concatStringsSep " " set.${ip} + "\n";
          allToString = set: lib.concatMapStrings (oneToString set) (lib.attrNames set);
        in
          allToString (lib.filterAttrs (_: v: v != [ ]) cfg.hosts)
      ;

      # /etc/services: TCP/UDP port assignments.
      services.source = pkgs.iana-etc + "/etc/services";

      # /etc/protocols: IP protocol numbers.
      protocols.source  = pkgs.iana-etc + "/etc/protocols";

      # /etc/netgroup: Network-wide groups.
      netgroup.text = lib.mkDefault "";

      # /etc/host.conf: resolver configuration file
      "host.conf".text = ''
        multi on
      '';

      hostid = lib.mkIf (cfg.hostId != null) { source = hostidFile; };
    } // lib.optionalAttrs (pkgs.stdenv.hostPlatform.libc == "glibc") {
      # /etc/rpc: RPC program numbers.
      rpc.source = pkgs.stdenv.cc.libc.out + "/etc/rpc";
    };
  };
}
