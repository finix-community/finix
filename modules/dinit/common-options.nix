{ config, lib, ... }:
{
  options = {
    # nix extensions to dinit services

    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to enable this service.
      '';
    };

    environment = lib.mkOption {
      type = with lib.types; attrsOf (either str int);
      default = { };
      example = {
        PATH = "/run/wrappers/bin";
        LANG = "en_US.UTF-8";
      };
      description = ''
        Environment variables passed to this service.
      '';
    };

    path = lib.mkOption {
      type = with lib.types; listOf (either package str);
      default = [ ];
      example = lib.literalExpression ''
        [
          pkgs.coreutils
          "/run/wrappers"
        ]
      '';
      description = ''
        Packages added to the `PATH` environment variable of this service.
      '';
    };

    # standard dinit options, applicable to both user and system level services

    type = lib.mkOption {
      type = lib.types.enum [
        "process"
        "bgprocess"
        "scripted"
        "internal"
        "triggered"
      ];
      default = "process";
      description = ''
        Specifies the service type.
        dinit has no useful default for services with a `command` (unset means `internal`),
        so we default to `process` here.

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#SERVICE_TYPES) for additional details.
      '';
    };

    command = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = ''
        Specifies the command, including command-line arguments, for starting the process.

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#SERVICE_TYPES) for additional details.
      '';
    };

    stop-command = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = ''
        Specifies the command to stop the service.

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#SERVICE_PROPERTIES) for additional details.
      '';
    };

    working-dir = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = ''
        Specifies the working directory for this service.

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#SERVICE_PROPERTIES) for additional details.
      '';
    };

    env-file = lib.mkOption {
      type = with lib.types; nullOr path;
      default = null;
      description = ''
        Specifies a file containing value assignments for environment variables.

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#SERVICE_PROPERTIES) for additional details.
      '';
    };

    depends-on = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = ''
        This service depends on the named service.

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#SERVICE_PROPERTIES) for additional details.
      '';
    };

    depends-ms = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = ''
        This service has a "milestone" dependency on the named service.

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#SERVICE_PROPERTIES) for additional details.
      '';
    };

    prepared-by = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = ''
        This service is prepared by the named service. Forces this service to restart when the named service does.

        See [Void Linux's documentation](https://man.voidlinux.org/dinit-service.5#prepared) for additional details.
      '';
    };

    waits-for = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = ''
        When this service is started, wait for the named service to finish starting (or to fail
        starting) before commencing the start procedure for this service.

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#SERVICE_PROPERTIES) for additional details.
      '';
    };

    after = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = ''
        When starting this service, if the named service is also starting, wait for the named service
        to finish starting before bringing this service up.

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#SERVICE_PROPERTIES) for additional details.
      '';
    };

    before = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = ''
        When starting the named service, if this service is also starting, wait for this service to
        finish starting before bringing the named service up.

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#SERVICE_PROPERTIES) for additional details.
      '';
    };

    chain-to = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = ''
        When this service terminates (i.e. starts successfully, and then stops of its own accord),
        the named service should be started.

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#SERVICE_PROPERTIES) for additional details.
      '';
    };

    pid-file = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = ''
        For `bgprocess` type services only; specifies the path of the file where daemon will write its
        process ID before detaching.

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#SERVICE_PROPERTIES) for additional details.
      '';
    };

    term-signal = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      example = "HUP";
      description = ''
        Specifies the signal to send to the process when requesting it to terminate.

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#SERVICE_PROPERTIES) for additional details.
      '';
    };

    start-timeout = lib.mkOption {
      type = with lib.types; nullOr numbers.nonnegative;
      default = null;
      description = ''
        Specifies the time in seconds allowed for the service to start.

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#SERVICE_PROPERTIES) for additional details.
      '';
    };

    stop-timeout = lib.mkOption {
      type = with lib.types; nullOr numbers.nonnegative;
      default = null;
      description = ''
        Specifies the time in seconds allowed for the service to stop.

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#SERVICE_PROPERTIES) for additional details.
      '';
    };

    restart = lib.mkOption {
      type = with lib.types; nullOr (either bool (enum [ "on-failure" ]));
      default = null;
      description = ''
        Indicates whether the service should automatically restart if it stops.

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#SERVICE_PROPERTIES) for additional details.
      '';
    };

    restart-delay = lib.mkOption {
      type = with lib.types; nullOr numbers.nonnegative;
      default = null;
      description = ''
        Specifies the minimum time (in seconds) between automatic restarts.

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#SERVICE_PROPERTIES) for additional details.
      '';
    };

    restart-limit-interval = lib.mkOption {
      type = with lib.types; nullOr numbers.nonnegative;
      default = null;
      description = ''
        Sets the interval (in seconds) over which restarts are limited.

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#SERVICE_PROPERTIES) for additional details.
      '';
    };

    restart-limit-count = lib.mkOption {
      type = with lib.types; nullOr ints.unsigned;
      default = null;
      description = ''
        Specifies the maximum number of times that a service can automatically restart over the interval specified
        by `restart-limit-interval`.

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#SERVICE_PROPERTIES) for additional details.
      '';
    };

    smooth-recovery = lib.mkOption {
      type = with lib.types; nullOr bool;
      default = null;
      description = ''
        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#SERVICE_PROPERTIES) for details.
      '';
    };

    log-type = lib.mkOption {
      type =
        with lib.types;
        nullOr (enum [
          "file"
          "buffer"
          "pipe"
          "none"
        ]);
      default = null;
      description = ''
        Specifies how the output of this service is logged.

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#SERVICE_PROPERTIES) for additional details.
      '';
    };

    logfile = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = ''
        Specifies the log file for the service.

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#SERVICE_PROPERTIES) for additional details.
      '';
    };

    logfile-permissions = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      example = "600";
      description = ''
        Gives the permissions for the log file specified using logfile.

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#SERVICE_PROPERTIES) for additional details.
      '';
    };

    log-buffer-size = lib.mkOption {
      type = with lib.types; nullOr ints.unsigned;
      default = null;
      description = ''
        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#SERVICE_PROPERTIES) for details.
      '';
    };

    consumer-of = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = ''
        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#SERVICE_PROPERTIES) for details.
      '';
    };

    ready-notification = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      example = "pipefd:3";
      description = ''
        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#SERVICE_PROPERTIES) for details.
      '';
    };

    socket-listen = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = ''
        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#SERVICE_PROPERTIES) for details.
      '';
    };

    socket-permissions = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      example = "666";
      description = ''
        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#SERVICE_PROPERTIES) for details.
      '';
    };

    nice = lib.mkOption {
      type = with lib.types; nullOr (ints.between (-20) 19);
      default = null;
      description = ''
        Specifies the CPU priority of the process.

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#SERVICE_PROPERTIES) for additional details.
      '';
    };

    ioprio = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      example = "best-effort:4";
      description = ''
        Specifies the I/O priority class and value for the service's process(es).

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#SERVICE_PROPERTIES) for additional details.
      '';
    };

    oom-score-adj = lib.mkOption {
      type = with lib.types; nullOr (ints.between (-1000) 1000);
      default = null;
      description = ''
        Specifies the OOM killer score adjustment for the service's process(es).

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#SERVICE_PROPERTIES) for additional details.
      '';
    };

    rlimit-nofile = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      example = "1024:4096";
      description = ''
        Specifies the number of file descriptors that a process may have open simultaneously.

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#RESOURCE_LIMITS) for additional details.
      '';
    };

    rlimit-core = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = ''
        Specifies the maximum size of the core dump file that will be generated for the process if it crashes (in a way that would
        result in a core dump).

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#RESOURCE_LIMITS) for additional details.
      '';
    };

    rlimit-data = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = ''
        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#RESOURCE_LIMITS) for details.
      '';
    };

    rlimit-addrspace = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = ''
        Specifies the maximum size of the address space of the process.

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#RESOURCE_LIMITS) for additional details.
      '';
    };

    options = lib.mkOption {
      type =
        with lib.types;
        listOf (enum [
          "start-interruptible"
          "skippable"
          "signal-process-only"
          "always-chain"
          "kill-all-on-stop"
          "no-new-privs"
        ]);
      default = [ ];
      description = ''
        Specifies various options for this service.

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#SERVICE_PROPERTIES) for additional details.
      '';
    };

    load-options = lib.mkOption {
      type =
        with lib.types;
        listOf (enum [
          "export-passwd-vars"
          "export-service-name"
        ]);
      default = [ ];
      description = ''
        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html#SERVICE_PROPERTIES) for details.
      '';
    };
  };

  config.environment.PATH = lib.mkIf (config.path != [ ]) (lib.makeBinPath config.path);
}
