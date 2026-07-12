{ lib, format }:
{
  options = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to enable this stanza.
      '';
    };

    extraConfig = lib.mkOption {
      type = lib.types.separatedString " ";
      default = "";
      example = "";
      description = ''
        A place for `finit` configuration options which have not been added to the `nix` module yet.
      '';
    };

    conditions = lib.mkOption {
      type = with lib.types; coercedTo nonEmptyStr lib.singleton (listOf nonEmptyStr);
      apply = lib.unique;
      default = [ ];
      example = "pid/syslog";
      description = ''
        See [upstream documentation](https://finit-project.github.io/conditions/) for details.
      '';
    };

    description = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = ''
        A human-readable description of this service, displayed by `initctl`.
      '';
    };

    runlevels = lib.mkOption {
      type = lib.types.str; # TODO: string  matching 0-9S
      default = "234";
      description = ''
        See [upstream documentation](https://finit-project.github.io/runlevels/) for details.
      '';
    };

    cgroup = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "system";
        description = ''
          The name of the cgroup to place this process under.
        '';
      };

      delegate = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          For services that need to create their own child `cgroups` (container runtimes like `docker`, `podman`, `systemd-nspawn`, `lxc`, etc...).

          See [upstream documentation](https://finit-project.github.io/config/cgroups/#cgroup-delegation) for details.
        '';
      };

      settings = lib.mkOption {
        type = format.type;
        default = { };
        description = ''
          The cgroup settings to apply to this process.

          See [kernel documentation](https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v2.html) for additional details.
        '';
      };
    };
  };
}
