{
  config,
  pkgs,
  lib,
  ...
}:
{
  config = lib.mkIf config.security.shadow.enable {
    environment.etc."login.defs".imports = [
      (
        { config, lib, ... }:
        {
          options.settings = lib.mkOption {
            type = lib.types.submodule {
              freeformType = (pkgs.formats.keyValue { }).type;

              options = {
                DEFAULT_HOME = lib.mkOption {
                  description = "Indicate if login is allowed if we can't cd to the home directory.";
                  default = "yes";
                  type = lib.types.enum [
                    "yes"
                    "no"
                  ];
                };

                ENCRYPT_METHOD = lib.mkOption {
                  description = "This defines the system default encryption algorithm for encrypting passwords.";
                  # The default crypt() method, keep in sync with the PAM default
                  default = "YESCRYPT";
                  type = lib.types.enum [
                    "YESCRYPT"
                    "SHA512"
                    "SHA256"
                    "MD5"
                    "DES"
                  ];
                };

                SYS_UID_MIN = lib.mkOption {
                  description = "Range of user IDs used for the creation of system users by useradd or newusers.";
                  default = 400;
                  type = lib.types.int;
                };

                SYS_UID_MAX = lib.mkOption {
                  description = "Range of user IDs used for the creation of system users by useradd or newusers.";
                  default = 999;
                  type = lib.types.int;
                };

                UID_MIN = lib.mkOption {
                  description = "Range of user IDs used for the creation of regular users by useradd or newusers.";
                  default = 1000;
                  type = lib.types.int;
                };

                UID_MAX = lib.mkOption {
                  description = "Range of user IDs used for the creation of regular users by useradd or newusers.";
                  default = 29999;
                  type = lib.types.int;
                };

                SYS_GID_MIN = lib.mkOption {
                  description = "Range of group IDs used for the creation of system groups by useradd, groupadd, or newusers";
                  default = 400;
                  type = lib.types.int;
                };

                SYS_GID_MAX = lib.mkOption {
                  description = "Range of group IDs used for the creation of system groups by useradd, groupadd, or newusers";
                  default = 999;
                  type = lib.types.int;
                };

                GID_MIN = lib.mkOption {
                  description = "Range of group IDs used for the creation of regular groups by useradd, groupadd, or newusers.";
                  default = 1000;
                  type = lib.types.int;
                };

                GID_MAX = lib.mkOption {
                  description = "Range of group IDs used for the creation of regular groups by useradd, groupadd, or newusers.";
                  default = 29999;
                  type = lib.types.int;
                };

                TTYGROUP = lib.mkOption {
                  description = ''
                    The terminal permissions: the login tty will be owned by the TTYGROUP group,
                    and the permissions will be set to TTYPERM'';
                  default = "tty";
                  type = lib.types.str;
                };

                TTYPERM = lib.mkOption {
                  description = ''
                    The terminal permissions: the login tty will be owned by the TTYGROUP group,
                    and the permissions will be set to TTYPERM'';
                  default = "0620";
                  type = lib.types.str;
                };

                # Ensure privacy for newly created home directories.
                UMASK = lib.mkOption {
                  description = "The file mode creation mask is initialized to this value.";
                  default = "077";
                  type = lib.types.str;
                };
              };
            };
            default = { };
            description = "";
          };

          config.text =
            let
              toKeyValue = lib.generators.toKeyValue {
                mkKeyValue = lib.generators.mkKeyValueDefault { } " ";
              };
            in
            toKeyValue config.settings;
        }
      )
    ];
  };
}
