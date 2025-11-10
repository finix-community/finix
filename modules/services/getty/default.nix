{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.getty;
in
{
  options.services.getty = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to enable `getty`.
      '';
    };

    ttys = lib.mkOption {
      type = with lib.types; listOf str;
      default = [
        "tty1"
        "tty2"
        "tty3"
        "tty4"
        "tty5"
        "tty6"
      ];
      description = ''
        The list of tty devices on which to start a login prompt.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc.issue = lib.mkDefault {
      text = ''

        [1;32m<<< welcome to finix >>>[0m

      '';
    };

    finit.ttys = lib.genAttrs cfg.ttys (device: {
      description = "getty on ${device}";
      nowait = true;
    });
  };
}
