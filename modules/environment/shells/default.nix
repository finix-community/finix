{
  config,
  lib,
  utils,
  ...
}:
let
  atom = lib.types.oneOf [
    lib.types.int
    lib.types.str
    lib.types.path
  ];

  toStr = v: if lib.isPath v then "${v}" else toString v;

  sessionVarsScript = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: value: "export ${name}=${lib.escapeShellArg value}") (
      lib.filterAttrs (_: value: value != null) config.environment.variables
    )
  );
in
{
  options.environment.shells = lib.mkOption {
    type = with lib.types; listOf (either shellPackage path);
    default = [ ];
  };

  options.environment.variables = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.nullOr (lib.types.coercedTo atom lib.singleton (lib.types.listOf atom))
    );
    default = { };
    apply = lib.mapAttrs (
      _: value: if value == null then null else lib.concatMapStringsSep ":" toStr value
    );
    description = ''
      Environment variables to set for POSIX-compliant login shells (bash, zsh,
      dash, ...) via {file}`/etc/profile.d/`. Shells with non-POSIX syntax,
      such as `fish`, do not source these scripts and will not pick up these
      variables.

      The value of each variable can be a string, a path, an integer, or a
      list of those, in which case the list is joined with `:`.

      Setting a variable to `null` does not set anything on its own, but lets
      you override a value set by another module to effectively cancel it out.
    '';
    example = {
      EDITOR = "nvim";
      XDG_DATA_DIRS = [
        "/usr/share"
        "/usr/local/share"
      ];
    };
  };

  config = {
    environment.etc.shells.text = ''
      ${lib.concatStringsSep "\n" (map utils.toShellPath config.environment.shells)}
      /bin/sh
    '';

    environment.etc.profile.text = ''
      # /etc/profile: system-wide initialisation for POSIX login shells

      # Source the drop-in scripts.
      if [ -d /etc/profile.d ]; then
        for i in /etc/profile.d/*.sh; do
          [ -r "$i" ] && . "$i"
        done
        unset i
      fi
    '';

    environment.etc."profile.d/session-vars.sh" = lib.mkIf (config.environment.variables != { }) {
      text = sessionVarsScript;
    };
  };
}
