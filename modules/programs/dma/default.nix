{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.dma;

  format = pkgs.formats.keyValue {
    mkKeyValue =
      name: value:
      if value == true then
        name
      else if value == false then
        "# ${name}"
      else
        lib.generators.mkKeyValueDefault { } " " name value;
  };
in
{
  options.programs.dma = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [dma](${cfg.package.meta.homepage}).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.dma;
      defaultText = lib.literalExpression "pkgs.dma";
      description = ''
        The package to use for `dma`.
      '';
    };

    settings = lib.mkOption {
      type = format.type;
      default = { };
      description = ''
        `dma` configuration. See {manpage}`dma(8)`
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc."dma/dma.conf".source = format.generate "dma.conf" cfg.settings;

    environment.systemPackages = [
      cfg.package
    ];

    finit.tmpfiles.rules = [
      "d /var/mail 2775 root mail - -"
      "d /var/spool/dma 2775 root mail - -"
    ];

    providers.scheduler.tasks.dma = {
      interval = "hourly";
      command = "${config.security.wrapperDir}/dma -q";
    };

    users.users = {
      mail = {
        isSystemUser = true;
        group = "mail";
      };
    };

    users.groups = {
      mail = { };
    };

    security.wrappers.dma = {
      source = "${cfg.package}/sbin/dma";
      owner = "root";
      group = "mail";
      setgid = true;
      permissions = "u+rwx,g+rx,o+rx";
    };

    security.wrappers.dma-mbox-create = {
      source = "${cfg.package}/lib/dma-mbox-create";
      owner = "root";
      group = "mail";
      setuid = true;
      permissions = "u+rwx,g+rx,o+r";
    };

    security.wrappers.sendmail = {
      source = "${cfg.package}/sbin/dma";
      owner = "root";
      group = "mail";
      setgid = true;
      permissions = "u+rwx,g+rx,o+rx";
    };
  };
}
