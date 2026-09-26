{
  modules,
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.lix-daemon;
in
{
  imports = [
    modules.nix-daemon
    (lib.mkAliasOptionModule [ "services" "lix-daemon" ] [ "services" "nix-daemon" ])
  ];

  config = lib.mkIf cfg.enable {
    services.nix-daemon.package = lib.mkDefault pkgs.lix;

    # Required for sandboxed builds with pasta to work
    boot.kernelModules = [ "tun" ];
    services.mdevd.hotplugRules = lib.mkIf config.services.mdevd.enable (
      lib.mkBefore "net/tun 0:0 666"
    );
  };
}
