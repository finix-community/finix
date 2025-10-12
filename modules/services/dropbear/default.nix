{ config, pkgs, lib, ... }:
let
  cfg = config.services.dropbear;

  stateDir = "/var/lib/dropbear";

  keyOpts = { config, ... }: {
    options = {
      type = lib.mkOption {
        type = lib.types.enum [ "rsa" "ecdsa" "ed25519" ];
        default = "ed25519";
      };

      path = lib.mkOption {
        type = lib.types.path;
      };

      bits = lib.mkOption {
        type = with lib.types; nullOr int;
        default = null;
      };

      comment = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
      };
    };

    config = {
      path = lib.mkDefault "${stateDir}/dropbear_${config.type}_host_key";
    };
  };
in
{
  options.services.dropbear = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.dropbear;
    };

    hostKeys = lib.mkOption {
      type = with lib.types; listOf (submodule keyOpts);
      default = [ { /* default */ } ];
    };

    extraArgs = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
    };
  };

  config = lib.mkIf cfg.enable {
    services.dropbear.extraArgs = config.services.dropbear.hostKeys
      |> map (key: [ "-r" key.path ])
      |> lib.flatten
    ;

    environment.systemPackages = [
      cfg.package
    ];

    finit.tasks.dropbear-keygen = {
      description = "generate ssh host keys";
      log = true;
      command =
        let
          script = lib.concatMapStringsSep "\n" (key: ''
            if ! [ -s "${key.path}" ]; then
              ${cfg.package}/bin/dropbearkey -t ${key.type} -f "${key.path}" ${lib.optionalString (key.bits != null) "-s ${toString key.bits}"} ${lib.optionalString (key.comment != null) "-C \"${key.comment}\""}
            fi
          '') config.services.dropbear.hostKeys;
        in
          pkgs.writeShellScript "ssh-keygen.sh" script;
    };


    finit.services.dropbear = {
      description = "dropbear ssh daemon";
      conditions = [ "net/lo/up" "service/syslogd/ready" "task/dropbear-keygen/success" ];
      command = "${pkgs.dropbear}/bin/dropbear -F " + lib.escapeShellArgs cfg.extraArgs;
      cgroup.name = "user";
      log = true;
      nohup = true;

      # TODO: dropbear doesn't use PAM so we need to keep these variables in sync with security.pam.environment!
      # NOTE: dropbear will only respect PATH and LD_LIBRARY_PATH
      env = pkgs.writeText "dropbear.env" ''
        PATH=${config.security.wrapperDir}:/run/current-system/sw/bin
      '';
    };

    services.tmpfiles.dropbear.rules = [
      "d ${stateDir} 0755"
    ];
  };
}
