{
  config,
  pkgs,
  lib,
  ...
}:
let
  globalPackages = config.environment.commonPackages.global;
  finitPackages = config.environment.commonPackages.global;
  cfg = config.finit;
in
{
  imports = [
    ./initrd.nix
    ./mount.nix
    ./stage1.nix
    ./stage2.nix
    ./tmpfiles.nix
  ];

  config = {
    environment.commonPackages.finit = {
      inherit (globalPackages)
        sed
        grep
        find
        gzip
        ;
      # sed = globalPackages.sed;
      # grep = globalPackages.grep;
      # find = globalPackages.find;
      # gzip = globalPackages.gzip;
    };

    assertions = [
      {
        assertion = lib.versionAtLeast cfg.package.version "4.16";
        message = "finit version must be at least 4.16";
      }

      {
        assertion = config.finit.ttys != { };
        message = "you have not defined any ttys; consider importing and enabling the getty module";
      }
    ];

    # TODO: decide a reasonable default here... user can override if needed
    finit.path = [
      config.programs.coreutils.package
      cfg.package

      # required by finit on shutdown
      pkgs.util-linux.mount

      # for finit log rotation
    ]
    # pkgs.gzip
    # pkgs.findutils
    # pkgs.gnugrep
    # pkgs.gnused
    # all options moved into this attribute set.
    ++ (lib.unique (lib.attrsets.attrValues finitPackages));

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
