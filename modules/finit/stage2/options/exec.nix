{
  lib,
  format,
  program,
}:
{ config, name, ... }:
{
  options = import ../../lib/options/exec.nix { inherit lib program; } // {
    user = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = ''
        The user this service should be executed as.
      '';
    };

    group = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = ''
        The group this service should be executed as.
      '';
    };

    supplementary_groups = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = ''
        Explicitly specify supplementary groups, in addition to reading group membership from {file}`/etc/group`.
      '';
    };

    caps = lib.mkOption {
      type = with lib.types; coercedTo nonEmptyStr lib.singleton (listOf nonEmptyStr);
      apply = lib.unique;
      default = [ ];
      example = [ "^cap_net_bind_service" ];
      description = ''
        Allow services to run with minimal required privileges instead of running as `root`.
      '';
    };

    path = lib.mkOption {
      type = with lib.types; listOf (either package str);
      default = [ ];
      description = ''
        Packages added to the `PATH` environment variable of this service.
      '';
    };

    env = lib.mkOption {
      type = with lib.types; nullOr (either str path);
      default = null;
      description = "either a path or a path prefixed with a '-' to indicate a missing file is fine.";
    };

    environment = lib.mkOption {
      type = format.type;
      default = { };
      example = {
        TZ = "CET";
      };
      description = ''
        Environment variables passed to this service.
      '';
    };

    log = lib.mkOption {
      type = with lib.types; either bool nonEmptyStr;
      default = false;
      description = ''
        Redirect `stderr` and `stdout` of the application to a file or `syslog` using the native `logit`
        tool. This is useful for programs that do not support `syslog` on their own, which is sometimes
        the case when running in the foreground.

        See [upstream documentation](https://finit-project.github.io/config/logging/) for additional details.
      '';
    };

    manual = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        If a service should not be automatically started, it can be configured as
        manual. The service can then be started at any time by running `initctl start <service>`.
      '';
    };

    conflict = lib.mkOption {
      type = with lib.types; coercedTo nonEmptyStr lib.singleton (listOf nonEmptyStr);
      apply = lib.unique;
      default = [ ];
      description = ''
        If you have conflicting services and want to prevent them from starting.
      '';
    };

    pre = lib.mkOption {
      type = lib.types.nullOr program;
      default = null;
      description = ''
        A script which will be called before the service is started.
      '';
    };

    post = lib.mkOption {
      type = lib.types.nullOr program;
      default = null;
      description = ''
        A script which will be called after the service has stopped.
      '';
    };

    cleanup = lib.mkOption {
      type = lib.types.nullOr program;
      default = null;
      description = ''
        A script which will be called when the service is removed.
      '';
    };

    restart = lib.mkOption {
      type = lib.types.ints.between (-1) 255;
      default = 10;
      description = ''
        The number of times `finit` tries to restart a crashing service. When
        this limit is reached the service is marked crashed and must be restarted
        manually with `initctl restart NAME`.
      '';
    };

    restart_sec = lib.mkOption {
      type = with lib.types; nullOr ints.unsigned;
      default = null;
      description = ''
        The number of seconds before Finit tries to restart a crashing service, default: `2`
        seconds for the first five retries, then back-off to `5` seconds. The maximum of this
        configured value and the above (`2` and `5`) will be used.
      '';
    };

    respawn = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable endless restarts without counting toward the retry limit. When set, the service
        will be restarted indefinitely regardless of the `restart` limit.
      '';
    };
  };

  config =
    let
      value = lib.splitString "@" name;
    in
    {
      name = lib.head value;
      id =
        if lib.hasSuffix "@" name then
          "%i"
        else if lib.hasInfix "@" name then
          lib.elemAt value 1
        else
          null;

      environment.PATH = lib.mkIf (config.path != [ ]) (lib.makeBinPath config.path);
      env = lib.mkIf (config.environment != { }) (
        format.generate "${config.name}.env" config.environment
      );
    };
}
