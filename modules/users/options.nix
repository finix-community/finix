{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.users;
in
{
  options = {
    users.users = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, config, ... }:
          {
            options = {

              enable = lib.mkOption {
                type = lib.types.bool;
                default = true;
                example = false;
                description = ''
                  If set to false, the user account will not be created. This is
                  useful for when you wish to conditionally disable user accounts.
                '';
              };

              isSystemUser = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = ''
                  Indicates if the user is a system user or not. This option
                  only has an effect if {option}`uid` is
                  {option}`null`, in which case it determines whether
                  the user's UID is allocated in the range for system users
                  (below 1000) or in the range for normal users (starting at
                  1000).
                  Exactly one of `isNormalUser` and
                  `isSystemUser` must be true.
                '';
              };

              isNormalUser = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = ''
                  Indicates whether this is an account for a “real” user.
                  This automatically sets {option}`group` to `users`,
                  {option}`createHome` to `true`,
                  {option}`home` to {file}`/home/«username»`,
                  {option}`shell` to {option}`users.defaultUserShell`,
                  and {option}`isSystemUser` to `false`.
                  Exactly one of `isNormalUser` and `isSystemUser` must be true.
                '';
              };

              name = lib.mkOption {
                type = with lib.types; passwdEntry str;
                apply =
                  x:
                  assert (
                    builtins.stringLength x < 32
                    || abort "Username '${x}' is longer than 31 characters which is not allowed!"
                  );
                  x;
                description = ''
                  The name of the user account. If undefined, the name of the
                  attribute set will be used.
                '';
              };

              description = lib.mkOption {
                type = with lib.types; passwdEntry str;
                default = "";
                example = "Alice Q. User";
                description = ''
                  A short description of the user account, typically the
                  user's full name.  This is actually the “GECOS” or “comment”
                  field in {file}`/etc/passwd`.
                '';
              };

              uid = lib.mkOption {
                type = with lib.types; nullOr int;
                default = null;
                description = ''
                  The account UID. If the UID is null, a free UID is picked on
                  activation.
                '';
              };

              group = lib.mkOption {
                type = lib.types.str;
                apply =
                  x:
                  assert (
                    builtins.stringLength x < 32
                    || abort "Group name '${x}' is longer than 31 characters which is not allowed!"
                  );
                  x;
                default = "";
                description = "The user's primary group.";
              };

              extraGroups = lib.mkOption {
                type = with lib.types; listOf str;
                default = [ ];
                description = "The user's auxiliary groups.";
              };

              home = lib.mkOption {
                type = with lib.types; passwdEntry path;
                default = "/var/empty";
                description = "The user's home directory.";
              };

              createHome = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = ''
                  Whether to create the home directory and ensure ownership as well as
                  permissions to match the user.
                '';
              };

              password = lib.mkOption {
                type = with lib.types; nullOr str;
                default = null;
                description = ''
                  Specifies the hashed password for the user.
                '';
              };

              passwordFile = lib.mkOption {
                type = with lib.types; nullOr str;
                default = null;
                description = ''
                  The full path to a file that contains the hash of the user's
                  password. The password file is read on each system activation. The
                  file should contain exactly one line, which should be the password in
                  an encrypted form that is suitable for the `chpasswd -e` command.
                '';
              };

              packages = lib.mkOption {
                type = with lib.types; listOf package;
                default = [ ];
                example = lib.literalExpression "[ pkgs.firefox pkgs.thunderbird ]";
                description = ''
                  The set of packages that should be made available to the user.
                  This is in contrast to {option}`environment.systemPackages`,
                  which adds packages to all users.
                '';
              };

              shell = lib.mkOption {
                type = with lib.types; nullOr (either shellPackage (passwdEntry path));
                default = pkgs.shadow;
                defaultText = lib.literalExpression "pkgs.shadow";
                example = lib.literalExpression "pkgs.bashInteractive";
                description = ''
                  The path to the user's shell. Can use shell derivations,
                  like `pkgs.bashInteractive`. Don't
                  forget to enable your shell in
                  `programs` if necessary,
                  like `programs.zsh.enable = true;`.
                '';
              };

            };

            config = lib.mkMerge [
              {
                name = lib.mkDefault name;
              }
              (lib.mkIf config.isNormalUser {
                group = lib.mkDefault "users";
                createHome = lib.mkDefault true;
                home = lib.mkDefault "/home/${config.name}";
                shell = lib.mkDefault cfg.defaultUserShell;
                isSystemUser = lib.mkDefault false;
              })
            ];
          }
        )
      );
      default = { };
    };

    users.defaultUserShell = lib.mkOption {
      type = with lib.types; either shellPackage (passwdEntry path);
      default = pkgs.bashInteractive;
      defaultText = lib.literalExpression "pkgs.bashInteractive";
      example = lib.literalExpression "pkgs.zsh";
      description = ''
        The default shell assigned to user accounts created with
        {option}`isNormalUser = true`.
      '';
    };

    users.groups = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, config, ... }:
          {
            options = {
              name = lib.mkOption {
                type = with lib.types; passwdEntry str;
                description = ''
                  The name of the group. If undefined, the name of the attribute set
                  will be used.
                '';
              };

              gid = lib.mkOption {
                type = with lib.types; nullOr int;
                default = null;
                description = ''
                  The group GID. If the GID is null, a free GID is picked on
                  activation.
                '';
              };

              members = lib.mkOption {
                type = with lib.types; listOf (passwdEntry str);
                default = [ ];
                description = ''
                  The user names of the group members, added to the
                  `/etc/group` file.
                '';
              };
            };

            config = {
              name = lib.mkDefault name;

              members = lib.mapAttrsToList (n: u: u.name) (
                lib.filterAttrs (n: u: u.enable && lib.elem config.name u.extraGroups) cfg.users
              );
            };
          }
        )
      );
      default = { };
    };
  };
}
