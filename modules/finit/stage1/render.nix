{ lib }:
let
  serviceStr =
    svcType: svc:
    lib.concatStringsSep " " (
      [
        svcType
        "[${svc.runlevels}]"
      ]
      ++ lib.optional (svc.name or null != null) "name:${svc.name}"
      ++ lib.optional (svc.id or null != null) ":${svc.id}"
      ++ lib.optional (svc.respawn or false) "respawn"
      ++ lib.optional (svc.restart or null != null) "restart:${toString svc.restart}"
      ++ lib.optional (svc.notify or null != null) "notify:${svc.notify}"
      ++ lib.optional (svc.conditions or [ ] != [ ]) "<${lib.concatStringsSep "," svc.conditions}>"
      ++ lib.optional (svc.tty or null != null) "tty:${svc.tty}"
      ++ lib.optional (svc.extraConfig or "" != "") svc.extraConfig
      ++ lib.optional (svc.command or null != null) svc.command
      ++

        # tty specific options
        (lib.optional (svc.device or null != null) svc.device)
      ++ lib.optional (svc.baud or null != null) svc.baud
      ++ lib.optional (svc.noclear or false) "noclear"
      ++ lib.optional (svc.nowait or false) "nowait"
      ++ lib.optional (svc.nologin or false) "nologin"
      ++ lib.optional (svc.rescue or false) "rescue"
      ++ lib.optional (svc.notty or false) "notty"
      ++

        (lib.optional (svc.description != null) "-- ${svc.description}")
    );
in
{
  inherit serviceStr;
}
