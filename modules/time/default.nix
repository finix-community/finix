{
  config,
  pkgs,
  lib,
  ...
}:
let
  tzdir = "${pkgs.tzdata}/share/zoneinfo";

  nospace = str: lib.filter (c: c == " ") (lib.stringToCharacters str) == [ ];
in
{
  options.time.timeZone = lib.mkOption {
    type = lib.types.nullOr (lib.types.addCheck lib.types.str nospace) // {
      description = "null or string without spaces";
    };
    default = null;
  };

  config = {
    # TODO: environment variable TZDIR = "/etc/zoneinfo"

    finit.environment.TZDIR = tzdir;

    environment.etc.zoneinfo.source = tzdir;

    environment.etc.localtime = lib.mkIf (config.time.timeZone != null) {
      source = "/etc/zoneinfo/${config.time.timeZone}";
      mode = "direct-symlink";
    };
  };
}
