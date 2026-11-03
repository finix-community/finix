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

  encryptMethod = lib.toLower cfg.settings.ENCRYPT_METHOD;

  session_rundir =
    if config.services.sessiond.enable then
      "${config.services.sessiond.package}/lib/security/pam_sessiond.so"
    else if config.services.elogind.enable then
      "${pkgs.elogind}/lib/security/pam_elogind.so"
    else if config.services.seatd.enable then
      "${pkgs.pam_rundir}/lib/security/pam_rundir.so"
    else
      null;
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
    environment.etc."security/limits.conf".text = lib.mkDefault "";
    environment.etc."login.defs".source = format.generate "login.defs" cfg.settings;

    security.pam.services.login.rules = {
      account.unix = {
        order = 10900;
        control = "required";
        modulePath = "pam_unix.so";
      };

      auth = {
        unix-early = {
          order = 11500;
          control = "optional";
          modulePath = "pam_unix.so";
          settings = {
            likeauth = true;
            nullok = true;
          };
        };
        unix = {
          order = 12800;
          control = "sufficient";
          modulePath = "pam_unix.so";
          settings = {
            likeauth = true;
            nullok = true;
            try_first_pass = true;
          };
        };
        deny = {
          order = 13600;
          control = "required";
          modulePath = "pam_deny.so";
        };
      };

      password.unix = {
        order = 10200;
        control = "sufficient";
        modulePath = "pam_unix.so";
        settings = {
          nullok = true;
          ${encryptMethod} = true;
        };
      };

      session = {
        env = {
          order = 10100;
          control = "required";
          modulePath = "pam_env.so";
          settings = {
            conffile = "/etc/security/pam_env.conf";
            readenv = 0;
          };
        };
        unix = {
          order = 10200;
          control = "required";
          modulePath = "pam_unix.so";
        };
        loginuid = {
          order = 10300;
          control = "required";
          modulePath = "pam_loginuid.so";
        };
        limits = {
          order = 10400;
          control = "required";
          modulePath = "pam_limits.so";
          settings.conf = "/etc/security/limits.conf";
        };
        lastlog = {
          order = 10700;
          control = "required";
          modulePath = "${pkgs.util-linux.lastlog}/lib/security/pam_lastlog2.so";
          settings.silent = true;
        };
        rundir = lib.mkIf (session_rundir != null) {
          order = 12000;
          control = "optional";
          modulePath = session_rundir;
        };
      };
    };

    security.pam.services.su.rules = {
      account.unix = {
        order = 10900;
        control = "required";
        modulePath = "pam_unix.so";
      };

      auth = {
        rootok = {
          order = 10200;
          control = "sufficient";
          modulePath = "pam_rootok.so";
        };
        faillock = {
          order = 10400;
          control = "required";
          modulePath = "pam_faillock.so";
        };
        unix = {
          order = 11500;
          control = "sufficient";
          modulePath = "pam_unix.so";
          settings = {
            likeauth = true;
            try_first_pass = true;
          };
        };
        deny = {
          order = 12300;
          control = "required";
          modulePath = "pam_deny.so";
        };
      };

      password.unix = {
        order = 10200;
        control = "sufficient";
        modulePath = "pam_unix.so";
        settings = {
          nullok = true;
          ${encryptMethod} = true;
        };
      };

      session = {
        env = {
          order = 10100;
          control = "required";
          modulePath = "pam_env.so";
          settings = {
            conffile = "/etc/security/pam_env.conf";
            readenv = 0;
          };
        };
        unix = {
          order = 10200;
          control = "required";
          modulePath = "pam_unix.so";
        };
        limits = {
          order = 10300;
          control = "required";
          modulePath = "pam_limits.so";
        };
        xauth = {
          enable = config.programs.xorg.enable or false;
          order = 12100;
          control = "optional";
          modulePath = "pam_xauth.so";
          settings = {
            systemuser = 99;
            xauthpath = "${pkgs.xauth}/bin/xauth";
          };
        };
      };
    };

    security.pam.services.passwd.rules = {
      account.unix = {
        order = 10900;
        control = "required";
        modulePath = "pam_unix.so";
      };

      auth = {
        unix = {
          order = 11500;
          control = "sufficient";
          modulePath = "pam_unix.so";
          settings = {
            likeauth = true;
            try_first_pass = true;
          };
        };
        deny = {
          order = 12300;
          control = "required";
          modulePath = "pam_deny.so";
        };
      };

      password.unix = {
        order = 10200;
        control = "sufficient";
        modulePath = "pam_unix.so";
        settings = {
          nullok = true;
          ${encryptMethod} = true;
        };
      };

      session = {
        env = {
          order = 10100;
          control = "required";
          modulePath = "pam_env.so";
          settings = {
            conffile = "/etc/security/pam_env.conf";
            readenv = 0;
          };
        };
        unix = {
          order = 10200;
          control = "required";
          modulePath = "pam_unix.so";
        };
      };
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
