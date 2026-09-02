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
    ./options.nix
    ./tmpfiles.nix
  ];

  config = {
    assertions = [
      {
        assertion = lib.versionAtLeast cfg.package.version "5";
        message = "finit version must be at least 5";
      }

      {
        assertion = config.finit.ttys != { };
        message = "you have not defined any ttys; consider importing and enabling the getty module";
      }
    ];

    finit.settings = lib.mkMerge [
      {
        runlevel = cfg.runlevel;
        readiness = "none";
      }
      (lib.mkIf (cfg.environment != { }) { environment = cfg.environment; })
      (lib.mkIf (cfg.cgroups != { }) { cgroup = cfg.cgroups; })
      (lib.mkIf (cfg.rlimits != { }) { rlimit = cfg.rlimits; })
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
