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

  options.services.lix-daemon.package = lib.mkOptionDefault pkgs.lix;

  config = lib.mkIf cfg.enable {
    # Required for sandboxed builds with pasta to work
    boot.kernelModules = [ "tun" ];
    services.mdevd.hotplugRules = lib.mkIf config.services.mdevd.enable (
      lib.mkBefore "net/tun 0:0 666"
    );
  };
}
