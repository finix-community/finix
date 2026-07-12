{ lib, program }:
{ name, config, ... }:
{
  options =
    import ../../lib/options/tty.nix { inherit lib program; }
    // {
      id = lib.mkOption {
        type = with lib.types; nullOr nonEmptyStr;
        default = null;
        description = ''
          Explicit instance ID for the TTY. If not set, finit auto-derives it from the device name
          (e.g., `tty1` becomes `:1`, `ttyS0` becomes `:S0`).
        '';
      };
    };

  config = {
    device = lib.mkIf (config.command == null) (lib.mkDefault name);
  };
}