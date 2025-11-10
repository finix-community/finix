{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.xserver;

  # Map video driver names to driver packages. FIXME: move into card-specific modules.
  knownVideoDrivers = {
    # Alias so people can keep using "virtualbox" instead of "vboxvideo".
    virtualbox = {
      modules = [ pkgs.xorg.xf86videovboxvideo ];
      driverName = "vboxvideo";
    };

    # Alias so that "radeon" uses the xf86-video-ati driver.
    radeon = {
      modules = [ pkgs.xorg.xf86videoati ];
      driverName = "ati";
    };

    # modesetting does not have a xf86videomodesetting package as it is included in xorgserver
    modesetting = { };
  };

  configFile = pkgs.writeText "xorg.conf" ''
    Section "Files"
    ${lib.concatMapStrings (module: ''
      ModulePath "${module}/lib/xorg/modules"
    '') cfg.modules}
    EndSection

    Section "InputClass"
      Identifier "Keyboard catchall"
      MatchIsKeyboard "on"
      Option "XkbModel" "pc104"
      Option "XkbLayout" "us"
      Option "XkbOptions" "terminate:ctrl_alt_bksp"
      Option "XkbVariant" ""
    EndSection

    # Match on all types of devices but joysticks
    #
    # If you want to configure your devices, do not copy this file.
    # Instead, use a config snippet that contains something like this:
    #
    # Section "InputClass"
    #   Identifier "something or other"
    #   MatchDriver "libinput"
    #
    #   MatchIsTouchpad "on"
    #   ... other Match directives ...
    #   Option "someoption" "value"
    # EndSection
    #
    # This applies the option any libinput device also matched by the other
    # directives. See the xorg.conf(5) man page for more info on
    # matching devices.

    Section "InputClass"
            Identifier "libinput pointer catchall"
            MatchIsPointer "on"
            MatchDevicePath "/dev/input/event*"
            Driver "libinput"
    EndSection

    Section "InputClass"
            Identifier "libinput keyboard catchall"
            MatchIsKeyboard "on"
            MatchDevicePath "/dev/input/event*"
            Driver "libinput"
    EndSection

    Section "InputClass"
            Identifier "libinput touchpad catchall"
            MatchIsTouchpad "on"
            MatchDevicePath "/dev/input/event*"
            Driver "libinput"
    EndSection

    Section "InputClass"
            Identifier "libinput touchscreen catchall"
            MatchIsTouchscreen "on"
            MatchDevicePath "/dev/input/event*"
            Driver "libinput"
    EndSection

    Section "InputClass"
            Identifier "libinput tablet catchall"
            MatchIsTablet "on"
            MatchDevicePath "/dev/input/event*"
            Driver "libinput"
    EndSection


    Section "InputClass"
      Identifier "libinput mouse configuration"
      MatchDriver "libinput"
      MatchIsPointer "on"

      Option "AccelProfile" "adaptive"





      Option "LeftHanded" "off"
      Option "MiddleEmulation" "on"
      Option "NaturalScrolling" "off"

      Option "ScrollMethod" "twofinger"
      Option "HorizontalScrolling" "on"
      Option "SendEventsMode" "enabled"
      Option "Tapping" "on"

      Option "TappingDragLock" "on"
      Option "DisableWhileTyping" "off"


    EndSection
  '';
in
{
  options.services.xserver = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "xserver";
    };

    modules = lib.mkOption {
      type = with lib.types; listOf path;
      default = [ ];
      example = lib.literalExpression "[ pkgs.xf86_input_wacom ]";
      description = "Packages to be added to the module search path of the X server.";
    };

    videoDrivers = lib.mkOption {
      type = with lib.types; listOf str;
      default = [
        "modesetting"
        "fbdev"
      ];
      example = [
        "nvidia"
        "amdgpu-pro"
      ];
      description = ''
        The names of the video drivers the configuration
        supports. They will be tried in order until one that
        supports your card is found.
        Don't combine those with "incompatible" OpenGL implementations,
        e.g. free ones (mesa-based) with proprietary ones.

        For unfree "nvidia*", the supported GPU lists are on
        https://www.nvidia.com/object/unix.html
      '';
    };

    videoDriver = lib.mkOption {
      type = with lib.types; nullOr str;
      default = null;
      example = "i810";
      description = ''
        The name of the video driver for your graphics card.  This
        option is obsolete; please set the
        {option}`services.xserver.videoDrivers` instead.
      '';
    };

    drivers = lib.mkOption {
      type = with lib.types; listOf attrs;
      internal = true;
      description = ''
        A list of attribute sets specifying drivers to be loaded by
        the X11 server.
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
    environment.systemPackages = [
      pkgs.xorg.xorgserver.out
      pkgs.xorg.xf86inputevdev.out # get evdev.4 man page

      pkgs.xorg.xrandr
      pkgs.xorg.xrdb
      pkgs.xorg.setxkbmap
      pkgs.xorg.iceauth # required for KDE applications (it's called by dcopserver)
      pkgs.xorg.xlsclients
      pkgs.xorg.xset
      pkgs.xorg.xsetroot
      pkgs.xorg.xinput
      pkgs.xorg.xprop
      pkgs.xorg.xauth
      pkgs.xorg.xrefresh # optional (elem "virtualbox" cfg.videoDrivers)

      pkgs.xterm
    ];

    environment.etc = {
      "X11/xorg.conf".source = configFile;
      "X11/xorg.conf.d/10-evdev.conf".source =
        "${pkgs.xorg.xf86inputevdev.out}/share/X11/xorg.conf.d/10-evdev.conf";
      "X11/xkb".source = "${config.services.xserver.xkb.dir}";

      "X11/xorg.conf.d/00-keyboard.conf".text = with config.services.xserver; ''
        Section "InputClass"
          Identifier "Keyboard catchall"
          MatchIsKeyboard "on"
          Option "XkbModel" "${xkb.model}"
          Option "XkbLayout" "${xkb.layout}"
          Option "XkbOptions" "${xkb.options}"
          Option "XkbVariant" "${xkb.variant}"
        EndSection
      '';
    };

    environment.pathsToLink = [ "/share/X11" ];

    services.xserver.modules = lib.concatLists (lib.catAttrs "modules" cfg.drivers) ++ [
      pkgs.xorg.xorgserver.out
      pkgs.xorg.xf86inputevdev.out

      pkgs.xorg.xf86inputlibinput
    ];

    # FIXME: somehow check for unknown driver names.
    services.xserver.drivers = lib.flip lib.concatMap cfg.videoDrivers (
      name:
      let
        driver = lib.attrByPath [ name ] (
          if pkgs.xorg ? ${"xf86video" + name} then
            { modules = [ pkgs.xorg.${"xf86video" + name} ]; }
          else
            null
        ) knownVideoDrivers;
      in
      lib.optional (driver != null) (
        {
          inherit name;
          modules = [ ];
          driverName = name;
          display = true;
        }
        // driver
      )
    );
  };
}
