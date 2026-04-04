{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.users;

  # Returns a system path for a given shell package
  toShellPath =
    shell:
    if lib.types.shellPackage.check shell then
      "/run/current-system/sw${shell.shellPath}"
    else if lib.types.package.check shell then
      throw "${shell} is not a shell package"
    else
      shell;

  format = pkgs.formats.json { };
  configFile = format.generate "userborn.json" {
    groups = lib.mapAttrsToList (username: opts: {
      inherit (opts)
        name
        gid
        members
        ;
    }) cfg.groups;

    users = lib.mapAttrsToList (username: opts: {
      inherit (opts)
        name
        uid
        group
        description
        home
        ;

      hashedPassword = opts.password;
      hashedPasswordFile = opts.passwordFile;
      isNormal = opts.isNormalUser;
      shell = toShellPath opts.shell;
    }) (lib.filterAttrs (_: u: u.enable) cfg.users);
  };
in
{
  imports = [ ./options.nix ];

  config = {
    assertions = [
      {
        assertion = config.system.activation.enable;
        message = "this users implementation requires an activatable system";
      }
    ];

    system.activation.scripts.users = ''
      mkdir -p /etc

      ${pkgs.userborn}/bin/userborn ${configFile}
    '';

    finit.tmpfiles.rules = [
      "d /home"
    ]
    ++ lib.mapAttrsToList (username: opts: "d ${opts.home} 0700 ${opts.name} ${opts.group}") (
      lib.filterAttrs (
        _: opts: opts.enable && opts.createHome && opts.home != "/var/empty"
      ) config.users.users
    );

    # default user & group definitions
    users.users.root = {
      uid = 0;
      group = "root";
      shell = pkgs.bashInteractive;
      home = "/root";
      createHome = true;
    };

    users.users.nobody = {
      uid = 65534;
      group = "nogroup";
    };

    users.groups =
      lib.genAttrs
        [
          "adm"
          "audio"
          "cdrom"
          "dialout"
          "disk"
          "input"
          "kmem"
          "kvm"
          "lp"
          "nogroup"
          "root"
          "sgx"
          "shadow"
          "tape"
          "tty"
          "users"
          "utmp"
          "video"
          "wheel"
        ]
        (value: {
          gid = config.ids.gids.${value};
        });

    environment.etc = lib.mapAttrs' (
      _:
      { packages, name, ... }:
      {
        name = "profiles/per-user/${name}";
        value.source = pkgs.buildEnv {
          name = "user-environment";
          paths = packages;
          inherit (config.environment) pathsToLink;
          ignoreCollisions = true;

          # !!! Hacky, should modularise.
          # outputs TODO: note that the tools will often not be linked by default
          postBuild = ''
            # Remove wrapped binaries, they shouldn't be accessible via PATH.
            find $out/bin -maxdepth 1 -name ".*-wrapped" -type l -delete

            if [ -x $out/bin/glib-compile-schemas -a -w $out/share/glib-2.0/schemas ]; then
                $out/bin/glib-compile-schemas $out/share/glib-2.0/schemas
            fi

            ${config.environment.extraSetup}
          '';

        };
      }
    ) (lib.filterAttrs (_: u: u.packages != [ ]) cfg.users);
  };
}
