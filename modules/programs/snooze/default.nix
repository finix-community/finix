{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.snooze;

  mkDelayOption =
    description:
    lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = ''
        ${description}

        The duration is parsed as seconds, unless a postfix of `m` for minutes, `h` for hours, or `d` for days is used.
      '';
    };
  mkScheduleOption =
    default: description:
    lib.mkOption {
      type = lib.types.str;
      inherit default;
      description = ''
        ${description}

        The following syntax is used for the option:
          exact match: `3`, run on the 3rd
          alternation: `3,10,27`, run on the 3rd, 10th, and 27th
          range: `1-5`, run on the 1st through 5th
          star: `*`, run on every value
          repetition: `/5`, run every 5th value (5th, 10th, 15th, ...)
          shifted repetition: `2/5`, run every 5th value starting at 2 (7th, 12th, 17th, ...)
          and combinations of those: `1-10,15/5,28`.
      '';
    };
in
{
  imports = [
    ./providers.scheduler.nix
  ];

  options.programs.snooze = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable `snooze`.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.snooze;
      defaultText = lib.literalExpression "pkgs.snooze";
      description = ''
        The package to use for `snooze`.
      '';
    };

    tasks = lib.mkOption {
      description = ''
        Options for a `snooze` instance.
        See [snooze(1)](https://man.voidlinux.org/snooze.1) for additional details.
      '';
      type = lib.types.attrsOf (
        lib.types.submodule (
          { config, name, ... }:
          {
            options = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = true;
              };

              command = lib.mkOption {
                type = lib.types.str;
                description = "The command to execute.";
              };
              description = lib.mkOption {
                type = lib.types.str;
                default = "snooze: ${name}";
              };

              user = lib.mkOption {
                type = with lib.types; nullOr str;
                default = null;
                description = ''
                  The user this service should be executed as.
                '';
              };
              timeFile = lib.mkOption {
                type = with lib.types; nullOr path;
                default = "/var/cache/snooze/${name}";
                description = ''
                  Path to the timefile location.

                  If `timeFile` does not exist, it will be assumed outdated enough to ensure earliest execution.
                '';
              };
              timeWait = mkDelayOption ''
                When provided, execution will not start earlier than the mtime of `timeFile` plus `timeWait` seconds.
                When not provided, snooze will start finding the first matching time starting from the mtime of `timefile`, and taking `slack` into account. 
              '';
              randDelay = mkDelayOption ''
                Delay determination of scheduled time randomly up to `randDelay` seconds later.
              '';
              jitter = mkDelayOption ''
                Delay execution randomly up to `jitter` seconds later than scheduled time.
              '';
              slack = lib.mkOption {
                type = lib.types.str;
                default = "60";
                description = ''
                  Commands are executed even if they are `slack` seconds late.
                  This will not result in immediate execution unless `timeFile` is used.

                  The duration is parsed as seconds, unless a postfix of `m` for minutes, `h` for hours, or `d` for days is used.
                '';
              };

              schedule = {
                day = mkScheduleOption "*" "day of month (1..31)";
                weekday = mkScheduleOption "*" "weekday (0..7, sunday is 0 and 7)";
                month = mkScheduleOption "*" "month (1..12)";
                hour = mkScheduleOption "0" "hour (0..23)";
                minute = mkScheduleOption "0" "minute (0..59)";
                second = mkScheduleOption "0" "second (0..59)";
                day_of_year = mkScheduleOption "*" "day of year (1..366)";
                week_of_year = mkScheduleOption "*" "week of year (1..53)";
              };
            };

            config.timeFile = lib.mkDefault (
              if config.user != null then
                "/var/cache/snooze/${config.user}_${name}"
              else
                "/var/cache/snooze/${name}"
            );
          }
        )
      );
    };
  };

  config = lib.mkIf cfg.enable (
    let
      mkFlags =
        task:
        lib.concatStringsSep " " (
          [
            "-S '${task.schedule.second}'"
            "-M '${task.schedule.minute}'"
            "-H '${task.schedule.hour}'"
            "-d '${task.schedule.day}'"
            "-w '${task.schedule.weekday}'"
            "-m '${task.schedule.month}'"
            "-D '${task.schedule.day_of_year}'"
            "-W '${task.schedule.week_of_year}'"
            "-s ${task.slack}"
          ]
          ++ lib.optionals (task.randDelay != null) [ "-R ${task.randDelay}" ]
          ++ lib.optionals (task.jitter != null) [ "-J ${task.jitter}" ]
          ++ lib.optionals (task.timeWait != null) [ "-T ${task.timeWait}" ]
          ++ lib.optionals (task.timeFile != null) [ "-t ${task.timeFile}" ]
        );
      mkCommand =
        task:
        let
          touch = lib.getExe' config.programs.coreutils.package "touch";
        in
        lib.concatStringsSep " " (
          [
            "${lib.getExe cfg.package}"
            "${mkFlags task}"
            # "--"
          ]
          ++ (
            if task.timeFile == null then
              [ task.command ]
            else
              [
                "/bin/sh"
                "-c"
                (lib.escapeShellArg "${task.command} && umask 077 && ${touch} ${task.timeFile}")
              ]
          )
        );
    in
    {
      environment.systemPackages = [
        cfg.package
      ];

      # To allow for running it as a user.
      # The folder has open permissions. Each user needs to touch it's own timeFile with `umask 077`.
      finit.tmpfiles.rules = [
        "d /var/cache/snooze 0777"
      ];

      finit.services = lib.mapAttrs (name: task: {
        inherit (task) user description;
        command = mkCommand task;
        respawn = true;
        log = true;
      }) (lib.filterAttrs (_: task: task.enable) cfg.tasks);

      # this module supplies an implementation for `providers.scheduler`
      providers.scheduler.backend = lib.mkDefault "snooze";
    }
  );
}
