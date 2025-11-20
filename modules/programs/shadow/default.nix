{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.shadow;

  format = pkgs.formats.keyValue {
    mkKeyValue = lib.generators.mkKeyValueDefault { } " ";
  };
in
{
  options.programs.shadow = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to enable [shadow](${pkgs.shadow.meta.homepage}).

        ::: {.warning}
        The `shadow` authentication suite provides critical programs such as `su`, `login`, `passwd`.
        :::
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.shadow;
      defaultText = lib.literalExpression "pkgs.shadow";
      description = ''
        The package to use for `shadow`.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = format.type;

        options = {
          DEFAULT_HOME = lib.mkOption {
            type = lib.types.enum [
              "yes"
              "no"
            ];
            default = "yes";
            description = "Indicate if login is allowed if we can't cd to the home directory.";
          };

          ENCRYPT_METHOD = lib.mkOption {
            type = lib.types.enum [
              "YESCRYPT"
              "SHA512"
              "SHA256"
              "MD5"
              "DES"
            ];
            # The default crypt() method, keep in sync with the PAM default
            default = "YESCRYPT";
            description = "This defines the system default encryption algorithm for encrypting passwords.";
          };

          SYS_UID_MIN = lib.mkOption {
            type = lib.types.int;
            default = 400;
            description = "Range of user IDs used for the creation of system users by useradd or newusers.";
          };

          SYS_UID_MAX = lib.mkOption {
            type = lib.types.int;
            default = 999;
            description = "Range of user IDs used for the creation of system users by useradd or newusers.";
          };

          UID_MIN = lib.mkOption {
            type = lib.types.int;
            default = 1000;
            description = "Range of user IDs used for the creation of regular users by useradd or newusers.";
          };

          UID_MAX = lib.mkOption {
            type = lib.types.int;
            default = 29999;
            description = "Range of user IDs used for the creation of regular users by useradd or newusers.";
          };

          SYS_GID_MIN = lib.mkOption {
            type = lib.types.int;
            default = 400;
            description = "Range of group IDs used for the creation of system groups by useradd, groupadd, or newusers";
          };

          SYS_GID_MAX = lib.mkOption {
            type = lib.types.int;
            default = 999;
            description = "Range of group IDs used for the creation of system groups by useradd, groupadd, or newusers";
          };

          GID_MIN = lib.mkOption {
            type = lib.types.int;
            default = 1000;
            description = "Range of group IDs used for the creation of regular groups by useradd, groupadd, or newusers.";
          };

          GID_MAX = lib.mkOption {
            type = lib.types.int;
            default = 29999;
            description = "Range of group IDs used for the creation of regular groups by useradd, groupadd, or newusers.";
          };

          TTYGROUP = lib.mkOption {
            type = lib.types.str;
            default = "tty";
            description = ''
              The terminal permissions: the login tty will be owned by the TTYGROUP group,
              and the permissions will be set to TTYPERM.
            '';
          };

          TTYPERM = lib.mkOption {
            type = lib.types.str;
            default = "0620";
            description = ''
              The terminal permissions: the login tty will be owned by the TTYGROUP group,
              and the permissions will be set to TTYPERM.
            '';
          };

          # Ensure privacy for newly created home directories.
          UMASK = lib.mkOption {
            type = lib.types.str;
            default = "077";
            description = "The file mode creation mask is initialized to this value.";
          };
        };
      };
      default = { };
      description = ''
        `shadow` configuration. See {manpage}`login.defs(5)`
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc."login.defs".source = format.generate "login.defs" cfg.settings;

    security.pam.services.login = {
      text = ''
        # Account management.
        account required pam_unix.so # unix (order 10900)

        # Authentication management.
        auth optional pam_unix.so likeauth nullok # unix-early (order 11500)
        auth sufficient pam_unix.so likeauth nullok try_first_pass # unix (order 12800)
        auth required pam_deny.so # deny (order 13600)

        # Password management.
        password sufficient pam_unix.so nullok yescrypt # unix (order 10200)

        # Session management.
        session required pam_env.so conffile=/etc/security/pam_env.conf readenv=0 # env (order 10100)
        session required pam_unix.so # unix (order 10200)
        session required pam_loginuid.so # loginuid (order 10300)
        session required ${config.security.pam.package}/lib/security/pam_lastlog.so silent # lastlog (order 10700)

        ${lib.optionalString config.services.elogind.enable "session optional ${pkgs.elogind}/lib/security/pam_elogind.so"}
        ${lib.optionalString config.services.seatd.enable "session optional ${pkgs.pam_rundir}/lib/security/pam_rundir.so"}
      '';
    };

    security.pam.services.su = {
      text = ''
        # Account management.
        account required pam_unix.so # unix (order 10900)

        # Authentication management.
        auth sufficient pam_rootok.so # rootok (order 10200)
        auth required pam_faillock.so # faillock (order 10400)
        auth sufficient pam_unix.so likeauth try_first_pass # unix (order 11500)
        auth required pam_deny.so # deny (order 12300)

        # Password management.
        password sufficient pam_unix.so nullok yescrypt # unix (order 10200)

        # Session management.
        session required pam_env.so conffile=/etc/security/pam_env.conf readenv=0 # env (order 10100)
        session required pam_unix.so # unix (order 10200)
        session optional pam_xauth.so systemuser=99 xauthpath=${pkgs.xorg.xauth}/bin/xauth # xauth (order 12100)
      '';
    };

    security.pam.services.passwd = {
      text = ''
        # Account management.
        account required pam_unix.so # unix (order 10900)

        # Authentication management.
        auth sufficient pam_unix.so likeauth try_first_pass # unix (order 11500)
        auth required pam_deny.so # deny (order 12300)

        # Password management.
        password sufficient pam_unix.so nullok yescrypt # unix (order 10200)

        # Session management.
        session required pam_env.so conffile=/etc/security/pam_env.conf readenv=0 # env (order 10100)
        session required pam_unix.so # unix (order 10200)
      '';
    };

    security.wrappers =
      let
        mkSetuidRoot = source: {
          setuid = true;
          owner = "root";
          group = "root";
          inherit source;
        };
      in
      {
        su = mkSetuidRoot "${cfg.package.su}/bin/su";
        sg = mkSetuidRoot "${cfg.package.out}/bin/sg";
        newgrp = mkSetuidRoot "${cfg.package.out}/bin/newgrp";
        newuidmap = mkSetuidRoot "${cfg.package.out}/bin/newuidmap";
        newgidmap = mkSetuidRoot "${cfg.package.out}/bin/newgidmap";
      }
      //
        lib.optionalAttrs true # config.users.mutableUsers
          {
            # chsh = mkSetuidRoot "${cfg.package.out}/bin/chsh";
            passwd = mkSetuidRoot "${cfg.package.out}/bin/passwd";
          };
  };
}
