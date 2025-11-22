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
      };
    };
  };

  config = lib.mkIf config.boot.supportedFilesystems."fuse.mergerfs".enable {
    environment.systemPackages = [ pkgs.mergerfs ];
  };
}
