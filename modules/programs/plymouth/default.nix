{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.plymouth;

  format = pkgs.formats.ini { };

  configFile = format.generate "plymouthd.conf" cfg.settings;
in
{
  options.programs.plymouth = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [plymouth](${pkgs.plymouth.meta.homepage}).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default =
        (pkgs.plymouth.overrideAttrs (o: {
          mesonFlags = o.mesonFlags ++ [
            "-Druntime-plugins=false"
          ];
        })).override
          { systemdSupport = false; };
      defaultText = lib.literalExpression "pkgs.plymouth";
      description = ''
        The package to use for `plymouth`.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = format.type;

        options.Daemon = {
          Theme = lib.mkOption {
            type = lib.types.str;
            default = "finix-theme";
            description = ''
              The name of the `plymouth` theme to use. Must match the directory name
              of the theme within the theme package specified by {option}`programs.plymouth.theme`.
            '';
          };
        };
      };
      default = { };
      description = ''
        `plymouthd` configuration. See {manpage}`plymouthd(8)`
        for additional details.
      '';
    };

    font = lib.mkOption {
      type = lib.types.path;
      default = "${pkgs.dejavu_fonts.minimal}/share/fonts/truetype/DejaVuSans.ttf";
      defaultText = lib.literalExpression ''"''${pkgs.dejavu_fonts.minimal}/share/fonts/truetype/DejaVuSans.ttf"'';
      description = ''
        Font file made available for displaying text on the splash screen.
      '';
    };

    theme = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./finix-plymouth.nix { }; # TODO: upstream in nixpkgs?
      defaultText = lib.literalExpression "pkgs.plymouth-finix-theme";
      description = ''
        The package containing a `plymouth` theme.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    boot.kernelParams = [
      "splash"
    ]
    ++ lib.optionals cfg.debug [ "plymouth.debug" ];

    programs.plymouth.settings = {
      Daemon = {
        ShowDelay = 0;
        DeviceTimeout = 8;
        ThemeDir = "${cfg.theme}/share/plymouth/themes";
      };
    };

    boot.initrd.contents = [
      {
        # notify plymouth and the finit plymouth plugin that this is an initramfs - enables plymouth process survival across switch-root
        target = "/etc/initrd-release";
        source = pkgs.writeText "initrd-release" "FINIX_INITRD=1\n"; # TODO: generate a proper initrd-release, depends on generating a proper /etc/os-release
      }
      {
        target = "/etc/plymouth/plymouthd.conf";
        source = configFile;
      }
      {
        target = "/etc/plymouth/plymouthd.defaults";
        source = "${cfg.package}/share/plymouth/plymouthd.defaults";
      }
      {
        target = "/etc/plymouth/fonts/${builtins.baseNameOf cfg.font}";
        source = cfg.font;
      }
      {
        target = "/etc/fonts/fonts.conf";
        source = pkgs.writeText "fonts.conf" ''
          <?xml version="1.0"?>
          <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
          <fontconfig>
              <dir>/etc/plymouth/fonts</dir>
          </fontconfig>
        '';
      }
      { source = cfg.theme; }
      { source = "${cfg.package}/lib/plymouth"; }

      # TODO: create boot.initrd.extraPackages (bin) option
      {
        target = "/usr/local/bin/plymouth";
        source = "${cfg.package}/bin/plymouth";
      }
      {
        target = "/usr/local/bin/plymouthd";
        source = "${cfg.package}/bin/plymouthd";
      }
    ];
  };
}
