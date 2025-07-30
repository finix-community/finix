{ config, pkgs, lib, ... }:
let
  cfg = config.networking;
in
{
  options.networking = {
    hostName = lib.mkOption {
      type = lib.types.str;
      default = "finix";
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

    } // lib.optionalAttrs (pkgs.stdenv.hostPlatform.libc == "glibc") {
      # /etc/rpc: RPC program numbers.
      rpc.source = pkgs.stdenv.cc.libc.out + "/etc/rpc";
    };
  };
}
