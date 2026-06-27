{
  modules,
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.wireplumber;

  format = pkgs.formats.json { };
in
{
  imports = [ modules.pipewire ];

  options.programs.wireplumber = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [wireplumber](${pkgs.wireplumber.meta.homepage}).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.wireplumber.override (
        lib.optionalAttrs (config.services.mdevd.enable || config.services.keventd.enable) {
          pipewire = config.programs.pipewire.package;
        }
      );
      defaultText = lib.literalExpression "pkgs.wireplumber";
      description = ''
        The package to use for `wireplumber`.
      '';
    };

    settings = lib.mkOption {
      type = format.type;
      default = { };
      example = {
        "context.properties" = {
          # Output Debug log messages as opposed to only the default level (Notice)
          "log.level" = "D";
        };
        "monitor.bluez.rules" = [
          {
            matches = [
              {
                # Match any bluetooth device with ids equal to that of a WH-1000XM3
                "device.name" = "~bluez_card.*";
                "device.product.id" = "0x0cd3";
                "device.vendor.id" = "usb:054c";
              }
            ];
            actions = {
              update-props = {
                # Set quality to high quality instead of the default of auto
                "bluez5.a2dp.ldac.quality" = "hq";
              };
            };
          }
        ];
      };
      description = ''
        `wireplumber` configuration. See [the configuration file][docs]
        for additional details.

        [docs]: https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/conf_file.html
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.pipewire.enable = true;

    environment.systemPackages = [
      cfg.package
    ];

    environment.etc."wireplumber/wireplumber.conf.d/99-nixos.conf".source =
      format.generate "99-nixos.conf" cfg.settings;
  };
}
