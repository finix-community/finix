{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.sudo;
in
{
  imports = [
    ./providers.privileges.nix
  ];

  options.programs.sudo = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [sudo](${pkgs.sudo.meta.homepage}).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.sudo;
      defaultText = lib.literalExpression "pkgs.sudo";
      description = ''
        The package to use for `sudo`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
    ];

    security.pam.services.sudo.rules = {
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
          yescrypt = true;
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
          order = 12200;
          control = "required";
          modulePath = "pam_limits.so";
        };
      };
    };

    environment.etc.sudoers = {
      mode = "0440";
      text = lib.mkMerge [
        (lib.mkBefore ''
          # Don't edit this file. Set the NixOS options ‘security.sudo.configFile’
          # or ‘security.sudo.extraRules’ instead.
        '')

        (lib.mkAfter ''
          # Keep terminfo database for root and %wheel.
          Defaults:root,%wheel env_keep+=TERMINFO_DIRS
          Defaults:root,%wheel env_keep+=TERMINFO

          # keep NIXOS_NO_CHECK for `nixos-rebuild switch`
          Defaults env_keep+=NIXOS_NO_CHECK
        '')

        ''
          root    ALL=(ALL:ALL)    SETENV: ALL
          %wheel  ALL=(ALL:ALL)    SETENV: ALL
        ''
      ];

      source =
        let
          value =
            pkgs.runCommand "sudoers.in"
              {
                src = pkgs.writeText "sudoers.in" config.environment.etc."sudoers".text;
                preferLocalBuild = true;
              }
              # Make sure that the sudoers file is syntactically valid.
              "${pkgs.buildPackages.sudo}/sbin/visudo -f $src -c && cp $src $out";
        in
        lib.mkForce value;
    };

    security.wrappers =
      let
        owner = "root";
        group = "root";
        setuid = true;
        permissions = "u+rx,g+x,o+x";
      in
      {
        sudo = {
          source = lib.getExe cfg.package;
          inherit
            owner
            group
            setuid
            permissions
            ;
        };
        sudoedit = {
          source = "${cfg.package}/bin/sudoedit";
          inherit
            owner
            group
            setuid
            permissions
            ;
        };
      };

    # this module supplies an implementation for `providers.privileges`
    providers.privileges.backend = lib.mkDefault "sudo";
  };
}
