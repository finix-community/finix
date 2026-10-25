# test for services.wireguard module
#
# this test verifies that two nodes can bring up a wireguard tunnel and
# communicate over it.
let
  peer0 = {
    privateKey = "OPuVRS2T0/AtHDp3PXkNuLQYDiqJaBEEnYe42BSnJnQ=";
    publicKey = "IujkG119YPr2cVQzJkSLYCdjpHIDjvr/qH1w1tdKswY=";
  };

  peer1 = {
    privateKey = "uO8JVo/sanx2DOM0L9GUEtzKZ82RGkRnYgpaYc7iXmg=";
    publicKey = "Ks9yRJIi/0vYgRmn14mIOQRwkcUGBujYINbMpik2SBI=";
  };
in
{
  name = "wireguard";

  nodes.server =
    { pkgs, ... }:
    {
      services.getty.enable = true;
      services.keventd.enable = true;

      services.wireguard = {
        enable = true;
        interfaces.wg0 = {
          ips = [ "10.23.42.1/32" ];
          listenPort = 51820;
          privateKeyFile = toString (pkgs.writeText "wg-key" peer0.privateKey);
          peers = [
            {
              name = "client";
              inherit (peer1) publicKey;
              allowedIPs = [ "10.23.42.2/32" ];
            }
          ];
        };
      };
    };

  nodes.client =
    { pkgs, ... }:
    {
      services.getty.enable = true;
      services.keventd.enable = true;

      services.wireguard = {
        enable = true;
        interfaces.wg0 = {
          ips = [ "10.23.42.2/32" ];
          privateKeyFile = toString (pkgs.writeText "wg-key" peer1.privateKey);
          peers = [
            {
              name = "server";
              inherit (peer0) publicKey;
              allowedIPs = [ "10.23.42.1/32" ];
              endpoint = "192.168.1.2:51820";
              persistentKeepalive = 25;
              dynamicEndpointRefreshSeconds = 2;
            }
          ];
        };
      };
    };

  testScript = ''
    import datetime

    start_all()

    server.wait_for_console_text("entering runlevel 2")
    client.wait_for_console_text("entering runlevel 2")

    with subtest("interfaces are up"):
        server.wait_until_succeeds("initctl cond get task/wireguard-wg0/success", timeout=datetime.timedelta(seconds=30))
        client.wait_until_succeeds("initctl cond get task/wireguard-wg0/success", timeout=datetime.timedelta(seconds=30))
        server.succeed("ip addr show wg0 | grep 'inet 10.23.42.1'")
        client.succeed("ip addr show wg0 | grep 'inet 10.23.42.2'")

    with subtest("peers are configured"):
        server.wait_until_succeeds("wg show wg0 peers | grep '${peer1.publicKey}'", timeout=datetime.timedelta(seconds=30))
        client.wait_until_succeeds("initctl status wireguard-wg0-peer-server | grep running", timeout=datetime.timedelta(seconds=30))
        client.succeed("ip route show 10.23.42.1 | grep wg0")

    with subtest("ping over tunnel"):
        client.wait_until_succeeds("ping -c 1 10.23.42.1", timeout=datetime.timedelta(seconds=30))
        server.succeed("ping -c 1 10.23.42.2")

    with subtest("stopping the peer removes it"):
        server.succeed("initctl stop wireguard-wg0-peer-client")
        server.wait_until_fails("wg show wg0 peers | grep '${peer1.publicKey}'", timeout=datetime.timedelta(seconds=30))

    client.shutdown()
    server.shutdown()
  '';
}
