{
  lib,
  cfg,
  program,
}:
{ config, ... }:
{
  options = {
    nohup = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether this service supports reload on `SIGHUP`.
      '';
    };

    pid = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = ''
        See [upstream documentation](https://finit-project.github.io/config/services/) for details.
      '';
    };

    type = lib.mkOption {
      type = with lib.types; nullOr (enum [ "forking" ]);
      default = null;
      description = ''
        Service type. Set to `"forking"` for traditional daemons that fork
        to the background and use PID files for process tracking.
      '';
    };

    notify = lib.mkOption {
      type =
        with lib.types;
        nullOr (enum [
          "pid"
          "systemd"
          "s6"
          "none"
        ]);
      default = cfg.readiness;
      defaultText = lib.literalExpression "config.finit.readiness";
      description = ''
        See [upstream documentation](https://finit-project.github.io/config/service-sync/) for details.
      '';
    };

    reload = lib.mkOption {
      type = lib.types.nullOr program;
      default = null;
      apply =
        value:
        if value != null then "'" + (lib.removeSuffix "'" (lib.removePrefix "'" value)) + "'" else null;
      example = "kill -HUP $MAINPID";
      description = ''
        Some services do not support `SIGHUP` but may have other ways to update the configuration of a running daemon. When
        `reload` is defined it is preferred over `SIGHUP`. Like `systemd`, `finit` sets ``$MAINPID` as a convenience to scripts,
        which in effect also allow setting `reload` to `kill -HUP $MAINPID`.

        ::: {.note}
        `reload` is called as PID 1, without any timeout! Meaning, it is up to you to ensure the script is not blocking for
        seconds at a time or never terminates.
        :::
      '';
    };

    stop = lib.mkOption {
      type = lib.types.nullOr program;
      default = null;
      apply =
        value:
        if value != null then "'" + (lib.removeSuffix "'" (lib.removePrefix "'" value)) + "'" else null;
      description = ''
        Some services may require alternate methods to be stopped. If `stop` is defined it is preferred over `SIGTERM`. Similar
        to `reload`, `finit` sets `$MAINPID`.

        ::: {.note}
        `stop` is called as PID 1, without any timeout! Meaning, it is up to you to ensure the script is not blocking for
        seconds at a time or never terminates.
        :::
      '';
    };

    kill = lib.mkOption {
      type = with lib.types; nullOr (ints.between 1 300);
      default = null;
      defaultText = "3";
      description = ''
        The delay in seconds between `finit` sending a `SIGTERM` and a `SIGKILL`.
      '';
    };

    ready = lib.mkOption {
      type = lib.types.nullOr program;
      default = null;
      description = ''
        A script which will be called when the service is ready.
      '';
    };

    oncrash = lib.mkOption {
      type =
        with lib.types;
        nullOr (enum [
          "reboot"
          "script"
        ]);
      default = null;
      description = ''
        - `reboot` - when all retries have failed, and the service has crashed, if this option is set the system is rebooted.
        - `script` - similarly, but instead of rebooting, call the `post:script` action if set.
      '';
    };
  };

  config = {
    nohup = lib.mkDefault (config.notify == "s6");
  };
}
