{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.snooze;

  mkTimingOption =
    default: description:
    lib.mkOption {
      inherit default;
      type = with lib.types; nullOr str;
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

  pathOrStr = with lib.types; coercedTo path (x: "${x}") str;
  program =
    lib.types.coercedTo (
      lib.types.package
      // {
        # require mainProgram for this conversion
        check = v: v.type or null == "derivation" && v ? meta.mainProgram;
      }
    ) lib.getExe pathOrStr
    // {
      description = "main program, path or command";
      descriptionClass = "conjunction";
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

              description = lib.mkOption {
                type = lib.types.str;
                default = "snooze: ${name}";
              };

              script = lib.mkOption {
                type = lib.types.lines;
                default = "";
                description = ''
                  Shell commands executed as the main process.
                '';
              };

              command = lib.mkOption {
                type = program;
                description = "The command to execute.";
              };

              user = lib.mkOption {
                type = with lib.types; nullOr str;
                default = null;
                description = ''
                  The user this service should be executed as.
                '';
              };
              timeFile = lib.mkOption {
                type = with lib.types; nullOr str;
                defaultText = lib.literalExpression ''
                  "/var/cache/snooze/{name}"
                  or when user is specified:
                  "/var/cache/snooze/{user}/{name}"
                '';
                description = ''
                  Path of the timefile location.

                  If `timeFile` does not exist, it will be assumed outdated enough to ensure earliest execution.
                '';
              };

              timing = {
                timeWait = mkTimingOption null ''
                  When provided, execution will not start earlier than the mtime of `timeFile` plus `timeWait` seconds.
                  When not provided, snooze will start finding the first matching time starting from the mtime of `timeFile`, and taking `slack` into account. 
                '';
                randDelay = mkTimingOption null ''
                  Delay determination of scheduled time randomly up to `randDelay` seconds later.
                '';
                jitter = mkTimingOption null ''
                  Delay execution randomly up to `jitter` seconds later than scheduled time.
                '';
                slack = mkTimingOption "60" ''
                  Commands are executed even if they are `slack` seconds late.
                  This will not result in immediate execution unless `timeFile` is used.
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

            config = {
              timeFile = lib.mkDefault (
                if config.user != null then
                  "/var/cache/snooze/${config.user}/${name}"
                else
                  "/var/cache/snooze/${name}"
              );

              command = lib.mkIf (config.script != "") (
                lib.mkForce (
                  pkgs.writeScript (lib.replaceStrings [ "@" ] [ "_" ] name) ''
                    #!/bin/sh
                    set -eu
                    ${config.script}
                  ''
                )
              );
            };
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
          ]
          ++ lib.optionals (task.timing.slack != null) [ "-s ${task.timing.slack}" ]
          ++ lib.optionals (task.timing.randDelay != null) [ "-R ${task.timing.randDelay}" ]
          ++ lib.optionals (task.timing.jitter != null) [ "-J ${task.timing.jitter}" ]
          ++ lib.optionals (task.timing.timeWait != null) [ "-T ${task.timing.timeWait}" ]
          ++ lib.optionals (task.timeFile != null) [ "-t '${task.timeFile}'" ]
        );
      mkCommand =
        name: task:
        let
          touch = lib.getExe' config.programs.coreutils.package "touch";
        in
        lib.concatStringsSep " " (
          [
            "${lib.getExe cfg.package}"
            "${mkFlags task}"
            "--"
          ]
          ++ (
            if task.timeFile == null then
              [ task.command ]
            else
              [
                (pkgs.writeScript "snooze-${name}-timefile.sh" ''
                  #!/bin/sh
                  set -eu
                  ${task.command};
                  ${touch} '${task.timeFile}' 
                '')
              ]
          )
        );

      users = lib.unique (
        lib.concatMap (t: lib.optional (t.enable && t.user != null && t.timeFile != null) t.user) (
          lib.attrValues cfg.tasks
        )
      );
    in
    {
      environment.systemPackages = [
        cfg.package
      ];

      finit.tmpfiles.rules = [
        "d /var/cache/snooze 0755"
      ]
      ++ map (u: "d /var/cache/snooze/${u} 0700 ${u}") users;

      finit.services = lib.mapAttrs (name: task: {
        inherit (task) user description;
        command = mkCommand name task;
        respawn = true;
        log = { };
      }) (lib.filterAttrs (_: task: task.enable) cfg.tasks);

      # this module supplies an implementation for `providers.scheduler`
      providers.scheduler.backend = "snooze";
    }
  );
}
