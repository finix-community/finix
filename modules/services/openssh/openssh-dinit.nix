{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.openssh;
  keygen = pkgs.writeShellScript "openssh-keygen-dinit" ''
    if ! [ -s /var/lib/sshd/ssh_host_ed25519_key ]; then
      ${cfg.package}/bin/ssh-keygen -t ed25519 -f /var/lib/sshd/ssh_host_ed25519_key -N ""
    fi
  '';
in
{
  config = lib.mkIf cfg.enable {
    dinit.services.ssh-keygen = {
      type = "scripted";
      command = toString keygen;
      targets = [ "local" ];
    };

    dinit.services.sshd = {
      type = "process";
      command = "${cfg.package}/bin/sshd -D -f /etc/ssh/sshd_config";
      waits-for =
        lib.optional (config.services ? sysklogd && config.services.sysklogd.enable) "syslogd"
        ++ [ "ssh-keygen" ];
      restart = true;
      smooth-recovery = true;
      targets = [ "network" ];
    };
  };
}
