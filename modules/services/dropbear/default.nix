{ config, pkgs, lib, ... }:
let
  cfg = config.services.dropbear;
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

    extraArgs = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
    ];

    finit.tasks.dropbear-keygen = {
      description = "generate ssh host keys";
      log = true;
      command = pkgs.writeShellScript "ssh-keygen.sh" ''
        if ! [ -s "/var/lib/dropbear/dropbear_ed25519_host_key" ]; then
          ${cfg.package}/bin/dropbearkey -t ed25519 -f "/var/lib/dropbear/dropbear_ed25519_host_key"
        fi
      '';
    };

    finit.services.dropbear = {
      description = "dropbear ssh daemon";
      conditions = [ "net/lo/up" "service/syslogd/ready" "task/dropbear-keygen/success" ];
      command = "${pkgs.dropbear}/bin/dropbear -F -r /var/lib/dropbear/dropbear_ed25519_host_key" + lib.escapeShellArgs cfg.extraArgs;
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
      "d /var/lib/dropbear 0755"
    ];
  };
}
