{ config, pkgs, lib, ... }:
let
  cfg = config.services.nzbget;
  stateDir = "/var/lib/nzbget";
  logDir = "/var/log/nzbget";
  configFile = "${stateDir}/nzbget.conf";
in
{
  options.services.nzbget = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [nzbget](${pkgs.nzbget.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nzbget;
      defaultText = lib.literalExpression "pkgs.nzbget";
      description = ''
        The package to use for `nzbget`.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "nzbget";
      description = ''
        User account under which `nzbget` runs.

        ::: {.note}
        If left as the default value this user will automatically be created
        on system activation, otherwise you are responsible for
        ensuring the user exists before the `nzbget` service starts.
        :::
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "nzbget";
      description = ''
        Group account under which `nzbget` runs.

        ::: {.note}
        If left as the default value this group will automatically be created
        on system activation, otherwise you are responsible for
        ensuring the group exists before the `nzbget` service starts.
        :::
      '';
    };

    settings = lib.mkOption {
      type = with lib.types; attrsOf (oneOf [ bool int str ]);
      default = { };
      description = ''
        `nzbget` configuration. See [upstream documentation](https://nzbget.com/documentation/command-line-reference)
        for additional details.
      '';
      example = {
        MainDir = "/data";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services.nzbget.settings = {
      MainDir = stateDir;

      # allows nzbget to run as a "simple" service
      OutputMode = "loggable";

      # use builtin nzbget logging
      LogFile = "${logDir}/nzbget.log";
      WriteLog = "rotate";
      ErrorTarget = "log";
      WarningTarget = "log";
      InfoTarget = "log";
      DetailTarget = "log";

      # required paths
      ConfigTemplate = "${cfg.package}/share/nzbget/nzbget.conf";
      WebDir = "${cfg.package}/share/nzbget/webui";
      SevenZipCmd = lib.getExe pkgs.p7zip;
      UnrarCmd = lib.getExe pkgs.unrar;

      # nixos handles package updates
      UpdateCheck = "none";
    };

    finit.services.nzbget =
      let
        configOpts = lib.concatStringsSep " " (lib.mapAttrsToList (name: value: "-o ${name}=${lib.escapeShellArg (toStr value)}") cfg.settings);
        toStr = v:
          if v == true then "yes"
          else if v == false then "no"
          else if lib.isInt v then toString v
          else v;

        script = pkgs.writeShellScript "nzbget.sh" ''
          exec ${lib.getExe cfg.package} --configfile ${configFile} ${configOpts} "$@"
        '';
      in
      {
        inherit (cfg) user group;

        description = "nzbget daemon";
        conditions = [ "service/syslogd/ready" ];
        command = "${script} --server";
        stop = "${script} --quit";
        reload = "${script} --reload";

        pre = pkgs.writeShellScript "nzbget-pre.sh" ''
          if [ ! -f ${configFile} ]; then
            ${pkgs.coreutils}/bin/install -o ${cfg.user} -g ${cfg.group} -m 0700 ${cfg.package}/share/nzbget/nzbget.conf ${configFile}
          fi
        '';
      };

    services.tmpfiles.nzbget.rules = [
      "d ${stateDir} 0750 ${cfg.user} ${cfg.group}"
      "d ${logDir} 0750 ${cfg.user} ${cfg.group}"
    ];

    users.users = lib.mkIf (cfg.user == "nzbget") {
      nzbget = {
        home = stateDir;
        group = cfg.group;
        uid = config.ids.uids.nzbget;
      };
    };

    users.groups = lib.mkIf (cfg.group == "nzbget") {
      nzbget = {
        gid = config.ids.gids.nzbget;
      };
    };
  };
}
