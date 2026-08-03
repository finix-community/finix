{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.openssh;
in
{
  config = lib.mkIf cfg.enable {
    finit.tasks.ssh-keygen = {
      description = "generate ssh host keys";
      log = true;
      command = pkgs.writeShellScript "ssh-keygen.sh" ''
        if ! [ -s "/var/lib/sshd/ssh_host_ed25519_key" ]; then
          ${cfg.package}/bin/ssh-keygen -t ed25519 -f "/var/lib/sshd/ssh_host_ed25519_key" -N ""
        fi
      '';
    };

    finit.services.sshd = {
      description = "openssh daemon";
      conditions = [
        "net/lo/up"
        "service/syslogd/ready"
        "task/ssh-keygen/success"
      ];
      notify = "pid";
      command = "${cfg.package}/bin/sshd -D -f /etc/ssh/sshd_config";
      cgroup.name = "user";
    };

    # TODO: add finit.services.reloadTriggers option
    environment.etc."finit.d/sshd.conf" = lib.mkIf (config.finit.services.sshd.enable) {
      text = lib.mkAfter ''

        # reload trigger
        # ${config.environment.etc."ssh/sshd_config".source}
      '';
    };
  };
}
