{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.boot.supportedFilesystems.fuse;
  cfgInitrd = config.boot.initrd.supportedFilesystems.fuse;
in
{
  options =
    let
      fuseEnable = default: {
        supportedFilesystems.fuse.enable = lib.mkOption {
          type = lib.types.bool;
          inherit default;
        };
      };
    in
    {
      boot = (fuseEnable true) // {
        initrd = fuseEnable false;
      };
    };

  config = lib.mkIf (cfg.enable || cfgInitrd.enable) {

    boot =
      let
        modsIf = v: lib.mkIf v [ "fuse" ];
      in
      {
        kernelModules = modsIf cfg.enable;
        initrd.kernelModules = modsIf cfgInitrd.enable;
      };

    security.wrappers =
      let
        mkSetuidRoot = source: {
          setuid = true;
          owner = "root";
          group = "root";
          inherit source;
        };
      in
      {
        fusermount = mkSetuidRoot "${pkgs.fuse}/bin/fusermount";
        fusermount3 = mkSetuidRoot "${pkgs.fuse3}/bin/fusermount3";
      };

    services.mdevd.hotplugRules = ''
      fuse 0:0 666
    '';
  };
}
