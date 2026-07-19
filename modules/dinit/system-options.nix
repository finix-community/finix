{ lib, ... }:
{
  # standard dinit options, applicable to only system level (privileged) services
  options = {
    run-as = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = ''
        Specifies which user to run the process(es) for this service as. Specify as a username or numeric ID.
      '';
    };

    logfile-uid = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = ''
        Specifies the user (name or numeric ID) that should own the log file. If `logfile-uid` is specified as a name without
        also specifying `logfile-gid`, then the log file group is the primary group of the specified user.
      '';
    };

    logfile-gid = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = ''
        Specifies the group of the log file. See discussion of `logfile-uid`.
      '';
    };

    socket-uid = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = ''
        Specifies the user (name or numeric ID) that should own the activation socket. If `socket-uid` is specified as a name
        without also specifying `socket-gid`, then the socket group is the primary group of the specified user.
      '';
    };

    socket-gid = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = ''
        Specifies the group of the activation socket. See discussion of `socket-uid`.
      '';
    };

    capabilities = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = ''
        Set the "IAB" capability vectors, which will determine the capabilities that the service process(es) are run with.
      '';
    };

    securebits = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = ''
        This is a companion option to `capabilities`, specifying the `securebits' flags for the service process(es).
      '';
    };

    run-in-cgroup = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = ''
        Run the service process(es) in the specified `cgroup`. The `cgroup` is specified as a path; if it has a leading slash,
        the remainder of the path is interpreted as relative to `/sys/fs/cgroup`.
      '';
    };

    inittab-id = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = ''
        When this service is started, if this setting (or the `inittab-line` setting) has a specified value, an entry will be
        created in the system `utmp` database.
      '';
    };

    inittab-line = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      description = ''
        This specifies the tty line that will be written to the `utmp` database when this service is started.
      '';
    };

    boot = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether this service is a hard dependency of the boot target.
        When true, the service is symlinked into boot.d/ — if it fails, boot fails.
      '';
    };
    default = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether this service is started via the default target.
        Unlike boot, this is a waits-for.d relationship — if the service
        fails, boot still succeeds.
      '';
    };

    # extend the common `options` flag enum with the privileged/console flags
    options = lib.mkOption {
      type =
        with lib.types;
        listOf (enum [
          "runs-on-console"
          "starts-on-console"
          "shares-console"
          "unmask-intr"
          "pass-cs-fd"
          "starts-rwfs"
          "starts-log"
        ]);
    };
  };
}
