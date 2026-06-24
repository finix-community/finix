{
  modules,
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.xorg;

  xf86-input-libinput' = pkgs.xf86-input-libinput.override (
    lib.optionalAttrs (config.services.mdevd.enable || config.services.keventd.enable) {
      xorg-server = cfg.package;
      libinput = pkgs.libinput.override {
        udev = pkgs.libudev-zero;
        wacomSupport = false;
      };
    }
  );
in
{
  imports = [
    ./nvidia.nix
    modules.xinit
  ];

  options.programs.xorg = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [xorg](${pkgs.xorg-server.meta.homepage}).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.xorg-server.override (
        lib.optionalAttrs (config.services.mdevd.enable || config.services.keventd.enable) {
          udev = pkgs.libudev-zero;
        }
      );
      defaultText = lib.literalExpression "pkgs.xorg-server";
      description = ''
        The package to use for `xorg`.
      '';
    };

    modules = lib.mkOption {
      type = with lib.types; listOf path;
      default = [ ];
      example = lib.literalExpression "[ pkgs.xf86-video-amdgpu pkgs.xf86_input_wacom ]";
      description = ''
        Packages added to the X server's module search path (ModulePath).

        The default driver, `modesetting`, is built into the server and covers
        practically all modern GPUs via KMS, so this is usually left empty.
        Add an `xf86-video-*` package only for hardware needing a specific
        legacy driver; the server auto-loads it during automatic
        configuration. Card-specific drivers that need explicit configuration
        (e.g. nvidia) are wired up by their own modules.
      '';
    };

    xkb = {
      layout = lib.mkOption {
        type = lib.types.str;
        default = "us";
        description = ''
          X keyboard layout, or multiple keyboard layouts separated by commas.
        '';
      };

      model = lib.mkOption {
        type = lib.types.str;
        default = "pc104";
        example = "presario";
        description = ''
          X keyboard model.
        '';
      };

      options = lib.mkOption {
        type = lib.types.commas;
        default = "terminate:ctrl_alt_bksp";
        example = "grp:caps_toggle,grp_led:scroll";
        description = ''
          X keyboard options; layout switching goes here.
        '';
      };

      variant = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "colemak";
        description = ''
          X keyboard variant.
        '';
      };

      dir = lib.mkOption {
        type = lib.types.path;
        default = "${pkgs.xkeyboard_config}/etc/X11/xkb";
        defaultText = lib.literalExpression ''"''${pkgs.xkeyboard_config}/etc/X11/xkb"'';
        description = ''
          Path used for -xkbdir xserver parameter.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.xinit.enable = true;
    programs.xorg.modules = [
      cfg.package.out
      xf86-input-libinput'
    ];

    environment.pathsToLink = [
      "/share/X11"
      "/share/xsessions"
    ];
    environment.systemPackages = [
      cfg.package.out
      pkgs.xauth
    ];

    # without elogind there are no device ACLs - X must run as root
    security.wrappers.X = {
      enable = !config.services.elogind.enable;
      setuid = true;
      owner = "root";
      group = "root";
      source = "${cfg.package.out}/bin/X";
    };

    environment.etc = {
      "X11/xkb".source = cfg.xkb.dir;

      "X11/xorg.conf.d/00-files.conf".source = pkgs.writeText "00-nixos.conf" ''
        Section "Files"
        ${lib.concatMapStringsSep "\n" (m: ''ModulePath "${m}/lib/xorg/modules"'') cfg.modules}
        EndSection
      '';

      "X11/xorg.conf.d/00-keyboard.conf".text = ''
        Section "InputClass"
          Identifier "Keyboard catchall"
          MatchIsKeyboard "on"
          Option "XkbModel" "${cfg.xkb.model}"
          Option "XkbLayout" "${cfg.xkb.layout}"
          Option "XkbOptions" "${cfg.xkb.options}"
          Option "XkbVariant" "${cfg.xkb.variant}"
        EndSection
      '';

      "X11/xorg.conf.d/40-libinput.conf".source =
        "${xf86-input-libinput'}/share/X11/xorg.conf.d/40-libinput.conf";
    };
  };
}
