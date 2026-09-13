{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.rsyslog;

  configFile = pkgs.writeText "rsyslog.conf" ''
    # Load necessary modules
    module(load="imuxsock")    # UNIX socket input (for local logging)
    module(load="imklog")      # Kernel log messages

    # Global settings
    $MaxMessageSize 64k
    $ModLoad immark
    $ActionFileDefaultTemplate RSYSLOG_TraditionalFileFormat
    $RepeatedMsgReduction on

    # Rate limiting
    $SystemLogRateLimitInterval 5
    $SystemLogRateLimitBurst 1000

    # Logging rules
    *.*;auth,authpriv.none      -/var/log/syslog
    auth,authpriv.*             -/var/log/auth.log
    kern.*                      -/var/log/kern.log
    mail.*                      -/var/log/mail.log
    cron.*                      -/var/log/cron.log
    daemon.*                    -/var/log/daemon.log
    user.*                      -/var/log/user.log
    *.emerg                     :omusrmsg:*
    *.alert                     -/var/log/alert.log

    $IncludeConfig /etc/rsyslog.d/*.conf
  '';
in
{
  options.services.rsyslog = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [rsyslog](${pkgs.rsyslog.meta.homepage}) as a system service.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    finit.services.syslogd = {
      description = "system logging daemon";
      runlevels = "S0123456789";
      # Daemon up, not full settle: coldplug/settle may be non-blocking or killed at the runlevel change
      # syslogd must not wait on their success
      conditions =
        lib.optionals config.services.gardendevd.enable [ "service/gardendevd/ready" ]
        ++ lib.optionals config.services.keventd.enable [ "service/keventd/ready" ]
        ++ lib.optionals config.services.udev.enable [ "service/udevd/ready" ]
        ++ lib.optionals config.services.mdevd.enable [ "service/mdevd/ready" ];
      command = "${pkgs.rsyslog-light}/bin/rsyslogd -n -d -f ${configFile}";
    };

    services.logrotate.rules.rsyslog = {
      text = ''
        /var/log/syslog
        /var/log/auth.log
        /var/log/kern.log
        /var/log/mail.log
        /var/log/cron.log
        /var/log/daemon.log
        /var/log/user.log
        /var/log/alert.log
        {
          rotate 7
          daily
          missingok
          notifempty
          compress
          delaycompress
          sharedscripts

          postrotate
            ${lib.getExe' config.programs.coreutils.package "kill"} -s HUP $(cat /run/rsyslog.pid)
          endscript
        }
      '';
    };
  };
}
