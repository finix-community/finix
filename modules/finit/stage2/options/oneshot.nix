{ lib }:
{
  options.remain = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      By default, a `run` or `task` will re-run each time its runlevel is
      entered, and its `post:` script does not run on completion.

      With `remain:yes`, the task runs once and does not re-run on runlevel. The
      `post:` script will run if the task is explicitly stopped or when the task
      leaves its valid runlevels.
    '';
  };
}
