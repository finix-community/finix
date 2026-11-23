{
  config,
  extendModules,
  lib,
  pkgs,
  ...
}:
let
  imageModules = {
    iso = ./iso.nix;
    qcow2 = ./qcow2.nix;
    raw = ./raw.nix;
  };

  deviceManagers = [
    "mdevd"
    "gardendevd"
    "udev"
    "keventd"
  ];

  # A variant must not re-enter image.modules
  noNestedImageModules = {
    options.image.modules = lib.mkOption {
      type = lib.types.attrsOf lib.types.deferredModule;
      apply = _: throw "image.modules cannot be set from within an image variant";
    };
  };

  imageConfigs = lib.mapAttrs (
    _: module:
    extendModules {
      modules = [
        module
        noNestedImageModules
      ];
    }
  ) config.image.modules;
in
{
  options.image = {
    modules = lib.mkOption {
      type = lib.types.attrsOf lib.types.deferredModule;
      description = ''
        Image-specific modules used for `system.build.images`.
      '';
    };

    baseName = lib.mkOption {
      type = lib.types.str;
      default = "finix-${config.networking.hostName}-${pkgs.stdenv.hostPlatform.system}";
      defaultText = lib.literalExpression ''"finix-''${config.networking.hostName}-''${pkgs.stdenv.hostPlatform.system}"'';
      description = ''
        Basename of the image filename without any extension.
      '';
    };

    extension = lib.mkOption {
      type = lib.types.str;
      description = ''
        Extension of the image filename (e.g. `iso`).
      '';
    };

    fileName = lib.mkOption {
      type = lib.types.str;
      default = "${config.image.baseName}.${config.image.extension}";
      defaultText = lib.literalExpression "config.image.baseName + \".\" + config.image.extension";
      description = ''
        Filename of the image including all extensions.
      '';
    };

    filePath = lib.mkOption {
      type = lib.types.str;
      default = config.image.fileName;
      defaultText = lib.literalExpression "config.image.fileName";
      description = ''
        Path of the image, relative to `$out` in `system.build.image`.
      '';
    };
  };

  config = {
    image.modules = imageModules;

    assertions = [
      {
        assertion = lib.any (name: config.services.${name}.enable) deviceManagers;
        message = ''
          Image blocks are found by /dev/disk/by-label, which needs a device manager.
          Enable one of: ${
            lib.concatStringsSep ", " (lib.map (name: "services.${name}.enable") deviceManagers)
          }.
        '';
      }
    ];

    system.build.images = lib.mapAttrs (
      _: imageConfig: imageConfig.config.system.build.image
    ) imageConfigs;

    system.build.isoImage = lib.mkDefault config.system.build.images.iso;
  };
}
