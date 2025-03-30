{ config, pkgs, lib, ... }:
let
  cfg = config.users;

  # Returns a system path for a given shell package
  toShellPath = shell:
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
      isNormal = opts.isNormalUser;
      shell = toShellPath opts.shell;
    }) cfg.users;
  };
in
{
  imports = [ ./options.nix ];

  config = {
    assertions = [
      { assertion = config.system.activation.enable; message = "this users implementation requires an activatable system"; }
    ];

    system.activation.scripts.users = lib.stringAfter [ "specialfs" ] ''
      echo "users stub here..."
      ${pkgs.userborn}/bin/userborn ${configFile}
    '';

    services.tmpfiles.home.rules = [ "d /home" ] ++ lib.mapAttrsToList (username: opts: "d ${opts.home} 0700 ${opts.name} ${opts.group}") (lib.filterAttrs (_: opts: opts.createHome && opts.home != "/var/empty") config.users.users);

    # default user & group definitions
    users.users.root = {
      uid = 0;
      group = "root";
      shell = pkgs.bashInteractive;
      home = "/root";
    };

    users.users.nobody = {
      uid = 65534;
      group = "nogroup";
    };

    users.groups = lib.genAttrs [
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
    ] (value: {
      gid = config.ids.gids.${value};
    });
  };
}
