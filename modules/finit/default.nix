{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.finit;
in
{
  imports = [
    ./initrd.nix
    ./mount.nix
    ./stage1
    ./stage2
    ./tmpfiles.nix
  ];

  config = {
    assertions = [
      {
        assertion = lib.versionAtLeast cfg.package.version "4.16";
        message = "finit version must be at least 4.16";
      }
    ];

    # TODO: decide a reasonable default here... user can override if needed
    finit.path = [
      config.programs.coreutils.package
      pkgs.findutils
      pkgs.gnugrep
      pkgs.gnused
      cfg.package

      # required by finit on shutdown
      pkgs.util-linux.mount

      # for finit log rotation
      pkgs.gzip
    ];

    finit.environment = lib.mkIf (cfg.path != [ ]) {
      PATH = lib.makeBinPath cfg.path;
    };

    environment.systemPackages = [
      cfg.package
    ];

    finit.tmpfiles.rules = [
      "d /etc/finit.d/enabled 0755"
    ];
  };
}
