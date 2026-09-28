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
    ./stage1.nix
    ./stage2.nix
    ./tmpfiles.nix
  ];

  config = {
    assertions = [
      {
        assertion = lib.versionAtLeast config.finit.package.version "5.0";
        message = "finit version must be at least 5.0";
      }

      {
        assertion = config.finit.ttys != { };
        message = "you have not defined any ttys; consider importing and enabling the getty module";
      }
    ];

    # PATH of `finit` itself, inherited by every stanza it runs.
    # Stanzas that need more set their own `path`.
    # Normal priority, so modules assigning `finit.path` extend it rather than replace it.
    finit.path = [
      cfg.package # initctl

      # required by finit on shutdown: remount / ro, swapoff /etc/fstab
      pkgs.util-linux
      # for finit log rotation
      pkgs.gzip

      # used by the stanzas generated here, e.g. printf in the mount-* tasks
      config.programs.coreutils.package
      pkgs.findutils
      pkgs.gnugrep
      pkgs.gnused
    ];

    # only the key, so overriding PATH does not conflict with i18n and time
    finit.environment.PATH = lib.mkIf (cfg.path != [ ]) (
      lib.mkDefault (lib.makeBinPath (lib.unique cfg.path))
    );

    environment.systemPackages = [
      cfg.package
    ];

    finit.tmpfiles.rules = [
      "d /etc/finit.d/enabled 0755"
    ];
  };
}
