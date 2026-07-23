{ lib }:
let
  logToStr = v: if v == true then "log" else "log:${v}";
  cgroupToStr =
    cgroup:
    let
      mkValueString =
        value:
        if lib.isString value then
          "'" + (lib.removeSuffix "'" (lib.removePrefix "'" value)) + "'"
        else
          toString value;

      options =
        lib.optional cgroup.delegate "delegate"
        ++ lib.mapAttrsToList (k: v: "${k}:${mkValueString v}") cgroup.settings;
    in
    "cgroup.${cgroup.name}"
    + lib.optionalString (options != [ ]) ",${lib.concatStringsSep "," options}";

  rlimitStr =
    let
      rlimitToStr =
        k: v:
        if lib.isAttrs v then
          (
            lib.optionalString (v.hard != null) "rlimit hard ${k} ${toString v.hard}"
            + lib.optionalString (v.hard != null && v.soft != null) "\n"
            + lib.optionalString (v.soft != null) "rlimit soft ${k} ${toString v.soft}"
          )
        else
          "rlimit ${k} ${toString v}";
    in
    values: lib.concatMapAttrsStringSep "\n" rlimitToStr values;

  mkConfigFile =
    svcType: svc:
    lib.optionalString (svc.rlimits or { } != { }) "${rlimitStr svc.rlimits}\n\n"
    + (serviceStr svcType svc);

  serviceStr =
    svcType: svc:
    lib.concatStringsSep " " (
      (lib.singleton svcType)
      ++ (lib.singleton "[${svc.runlevels}]")
      ++

        (lib.optional (svc.name or null != null) "name:${svc.name}")
      ++ (lib.optional (svc.id or null != null) ":${svc.id}")
      ++ (lib.optional (svc.cgroup.name or null != null || svc.cgroup.settings or { } != { }) (
        cgroupToStr svc.cgroup
      ))
      ++ (lib.optional (svc.restart or false != false) "restart:${toString svc.restart}")
      ++ (lib.optional (svc.restart_sec or null != null) "restart_sec:${toString svc.restart_sec}")
      ++ (lib.optional (svc.respawn or false) "respawn")
      ++ (lib.optional (svc.user or null != null) (
        "@${svc.user}"
        + lib.optionalString (svc.group != null) ":${svc.group}"
        + lib.optionalString (
          svc.supplementary_groups or [ ] != [ ]
        ) ",${lib.concatStringsSep "," svc.supplementary_groups}"
      ))
      ++ (lib.optional (svc.conditions or [ ] != [ ] || svc.nohup or false == true)
        "<${lib.optionalString (svc.nohup or false) "!"}${lib.concatStringsSep "," svc.conditions}>"
      )
      ++ (lib.optional (svc.manual or false) "manual:yes")
      ++ (lib.optional (svc.remain or false) "remain:yes")
      ++ (lib.optional (svc.kill or null != null) "kill:${toString svc.kill}")
      ++ (lib.optional (svc.caps or [ ] != [ ]) ("caps:${lib.concatStringsSep "," svc.caps}"))
      ++ (lib.optional (svc.conflict or [ ] != [ ]) ("conflict:${lib.concatStringsSep "," svc.conflict}"))
      ++ (lib.optional (svc.pid or null != null) "pid:${svc.pid}")
      ++ (lib.optional (svc.type or null != null) "type:${svc.type}")
      ++ (lib.optional (svc.notify or null != null) "notify:${svc.notify}")
      ++ (lib.optional (svc.env or null != null) "env:${svc.env}")
      ++ (lib.optional (svc.log or false != false) (logToStr svc.log))
      ++ (lib.optional (svc.tty or null != null) "tty:${svc.tty}")
      ++ (lib.optional (svc.reload or null != null) "reload:${svc.reload}")
      ++ (lib.optional (svc.stop or null != null) "stop:${svc.stop}")
      ++ (lib.optional (svc.pre or null != null) "pre:${svc.pre}")
      ++ (lib.optional (svc.post or null != null) "post:${svc.post}")
      ++ (lib.optional (svc.oncrash or null != null) "oncrash:${svc.oncrash}")
      ++ (lib.optional (svc.extraConfig or "" != "") svc.extraConfig)
      ++ (lib.optional (svc.command != null) svc.command)
      ++

        # tty specific options
        (lib.optional (svc.device or null != null) svc.device)
      ++ (lib.optional (svc.baud or null != null) svc.baud)
      ++ (lib.optional (svc.noclear or false) "noclear")
      ++ (lib.optional (svc.nowait or false) "nowait")
      ++ (lib.optional (svc.nologin or false) "nologin")
      ++ (lib.optional (svc.rescue or false) "rescue")
      ++ (lib.optional (svc.notty or false) "notty")
      ++ (lib.optional (svc.term or null != null) svc.term)
      ++

        (lib.optional (svc.description != null) "-- ${svc.description}")
    );
in
{
  inherit
    logToStr
    cgroupToStr
    rlimitStr
    mkConfigFile
    serviceStr
    ;
}
