{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.seatd;
in
{
  imports = [
    ./seatd-dinit.nix
    ./seatd-finit.nix
  ];

  options.services.seatd = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [seatd](${pkgs.seatd.meta.homepage}) as a system service.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "seat";
      description = ''
        Group to own the `seatd` socket.

        ::: {.note}
        If you want non-`root` users to be able to access the `seatd` session, add
        them to this group.
        :::
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups = lib.optionalAttrs (cfg.group == "seat") {
      seat = { };
    };

  };
}
