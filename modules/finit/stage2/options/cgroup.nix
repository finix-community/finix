{ lib, format }:
{ name, ... }:
{
  options = {
    name = lib.mkOption {
      type = lib.types.str; # TODO: add constraints based on finit
      default = name;
      description = ''
        The name of the cgroup to create.
      '';
    };

    settings = lib.mkOption {
      type = format.type;
      default = { };
      example = {
        "cpu.weight" = 100;
      };
      description = ''
        Settings to apply to this cgroup.

        See [kernel documentation](https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v2.html) for additional details.
      '';
    };
  };
}
