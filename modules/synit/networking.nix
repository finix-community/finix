{ lib, config, pkgs, ... }:

let
  cfg = config.networking;

  inherit (builtins) toJSON;
  inherit (lib)
    mkIf
    getExe'
    ;
in
{
  config = mkIf config.synit.enable {

    # Collect information on network devices when triggered
    # by uevent and assert it into the machine dataspace.
    services.mdevd.hotplugRules =
      "-SUBSYSTEM=net;DEVPATH=.*/net/*;.* 0:0 600 &${pkgs.synit-network-utils}/lib/mdev-hook.el";

    # A Tcl script responds to assertions in the 
    # network dataspace by executing iproute2 commands
    # and relaying actually existing configuration into
    # the machine dataspaces.
    synit.daemons.network-configurator =
      let inherit (pkgs.tclPackages) sycl; in {
        argv = lib.quoteExecline [
          "if" [ "resolvconf" "-I" ]
          "network-configurator"
        ];
        path = builtins.attrValues {
          inherit (pkgs) iproute2 openresolv synit-network-utils;
        };
        protocol = "text/syndicate";
        provides = [ [ "milestone" "network" ] ];
        requires = [ { key = [ "daemon" "sysctl" ]; state = "complete"; } ];
        readyOnStart = false;
      };

    synit.plan.config = {
      network = [ (builtins.readFile "${pkgs.synit-network-utils.src}/network.pr") ];
    };
  };
}
