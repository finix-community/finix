{
  config,
  lib,
  ...
}:
let
  cfg = config.services.nix-daemon;
in
{
  config = lib.mkIf cfg.enable {
    dinit.services.nix-daemon = {
      type = "process";
      command = "${cfg.package}/bin/nix-daemon --daemon";
      restart = true;
      targets = [ "local" ];
      smooth-recovery = true;
      waits-for =
        lib.optional (config.services ? sysklogd && config.services.sysklogd.enable) "syslogd"
        ++ [ "tmpfiles-setup" ];
      log-type = "file";
      logfile = "/var/log/nix-daemon.log";
      rlimit-nofile = "1048576:1048576";
      environment.CURL_CA_BUNDLE = config.security.pki.caBundle;
    };
  };
}
