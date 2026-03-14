{
  config,
  pkgs,
  lib,
  ...
}:
{
  options = {
    boot.supportedFilesystems."fuse.mergerfs" = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable support for the `mergerfs` fuse filesystem.
        '';
      };
    };
  };

  config = lib.mkIf config.boot.supportedFilesystems."fuse.mergerfs".enable {
    boot.initrd.kernelModules = [
      "fuse"
    ];

    environment.systemPackages = [ pkgs.mergerfs ];
  };
}
