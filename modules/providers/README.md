- `providers.` namespace is a mechanism to abstract software implementations from high level concepts
- `providers.scheduler` - a high level abstraction over `cron` (`fcron`, `mcron`, `jobber`, `systemd.timers`, etc...), for example:

```
  providers.scheduler.tasks = {
    logrotate = {
      interval = "hourly";
      command = "${cfg.package}/bin/logrotate ${configFile}";
    };
  };
```

- `providers.privileges` - a high level abstraction over `sudo` (`sudo-rs`, `doas`, `please`, etc...), for example:

```
  providers.privileges.rules = [
    { command = "/run/current-system/sw/bin/reboot";
      groups = [ "automation" ];
    }
  ];
```
