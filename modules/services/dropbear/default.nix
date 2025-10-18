{ config, pkgs, lib, ... }:
let
  cfg = config.services.dropbear;

  stateDir = "/var/lib/dropbear";

  keyOpts = { config, ... }: {
    options = {
      type = lib.mkOption {
        type = lib.types.enum [ "rsa" "ecdsa" "ed25519" ];
        default = "ed25519";
        description = ''
          The type of key to generate.
        '';
      };

      path = lib.mkOption {
        type = lib.types.path;
        description = ''
          Write the secret key to this path.
        '';
      };

      bits = lib.mkOption {
        type = with lib.types; nullOr int;
        default = null;
        description = ''
          Set the key size in bits.

          ::: {.note}
          Should be multiple of `8`.
          :::
        '';
      };

      comment = lib.mkOption {
        type = with lib.types; nullOr str;
        default = null;
        description = ''
          Specify the key comment (email).
        '';
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
      description = ''
        Whether to enable [dropbear](${pkgs.dropbear.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.dropbear;
      defaultText = lib.literalExpression "pkgs.dropbear";
      description = ''
        The package to use for `dropbear`.
      '';
    };

    hostKeys = lib.mkOption {
      type = with lib.types; listOf (submodule keyOpts);
      default = [ { /* default */ } ];
      defaultText = [
        { type = "ed25519"; path = "${stateDir}/dropbear_ed25519_host_key"; }
      ];
      description = ''
        `finix` will automatically generate SSH host keys using {manpage}`dropbearkey(1)` on startup.

        ::: {.note}
        Automatic generation of host keys can be disabled by setting a value of `lib.mkForce [ ]`.
        :::
      '';
    };

    extraArgs = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = ''
        Additional arguments to pass to `dropbear`. See {manpage}`dropbear(8)`
        for additional details.
      '';
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
