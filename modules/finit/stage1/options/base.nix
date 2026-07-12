{ lib }:
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
      default = "S";
      description = ''
        See [upstream documentation](https://finit-project.github.io/runlevels/) for details.
      '';
    };
  };
}
