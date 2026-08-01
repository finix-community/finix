{ lib }:
let
  root = "boot";

  definitions = {
    boot = {
      type = "internal";
      "depends-on.d" = "boot.d";
    };

    "filesystem.target" = {
      type = "internal";
      "depends-on.d" = "filesystem.d";
    };

    "local.target" = {
      type = "internal";
      "waits-for.d" = "local.d";
      "waits-for" = "filesystem.target";
    };

    "network.target" = {
      type = "internal";
      "waits-for.d" = "network.d";
      "waits-for" = "local.target";
    };

    "login.target" = {
      type = "internal";
      "waits-for.d" = "login.d";
      "waits-for" = "local.target";
    };
  };
in
{
  inherit root definitions;

  names = map (lib.removeSuffix ".target") (
    lib.filter (name: name != root) (lib.attrNames definitions)
  );
}
