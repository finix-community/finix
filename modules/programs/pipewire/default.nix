{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.programs.pipewire;

  format = pkgs.formats.json { };

  configFiles =
    let
      mkConf =
        file: settings:
        lib.optionalAttrs (settings != { }) {
          "share/pipewire/${file}.d/99-nixos.conf" = format.generate "99-nixos.conf" settings;
        };
      files =
        mkConf "pipewire.conf" cfg.settings
        // mkConf "client.conf" cfg.client.settings
        // mkConf "jack.conf" cfg.jack.settings
        // mkConf "pipewire-pulse.conf" cfg.pulse.settings;
    in
    pkgs.runCommandLocal "pipewire-generated-config" { } ''
      mkdir -p $out
      ${lib.concatStringsSep "\n" (
        lib.mapAttrsToList (path: src: ''
          mkdir -p "$out/$(dirname ${lib.escapeShellArg path})"
          ln -s ${src} "$out/${path}"
        '') files
      )}
    '';

  configDir =
    pkgs.runCommand "pipewire-config"
      {
        __structuredAttrs = true;
        preferLocalBuild = true;
        allowSubstitutes = false;
        packages = lib.unique (cfg.packages ++ [ configFiles ]);
      }
      ''
        mkdir -p $out
        shopt -s nullglob

        for pkg in "''${packages[@]}"; do
          for dir in "$pkg"/share/pipewire/*.conf.d; do
            loc=$(basename "$dir")
            mkdir -p "$out/$loc"
            for file in "$dir"/*; do
              ln -sf "$file" "$out/$loc/$(basename "$file")"
            done
          done
        done
      '';

  enable32BitAlsaPlugins =
    cfg.alsa.support32Bit && pkgs.stdenv.hostPlatform.isx86_64 && pkgs.pkgsi686Linux.pipewire != null;

  pipewire' =
    (pkgs.pipewire.override (
      lib.optionalAttrs (config.services.mdevd.enable || config.services.keventd.enable) {
        enableSystemd = false;
        udev = pkgs.libudev-zero;
      }
    )).overrideAttrs
      (o: {
        # https://gitlab.freedesktop.org/pipewire/pipewire/-/issues/2398#note_2967898
        patches =
          o.patches or [ ]
          ++ lib.optionals (config.services.mdevd.enable || config.services.keventd.enable) [
            ./pipewire.patch
          ];
      });

  pipewire32' =
    (pkgs.pkgsi686Linux.pipewire.override (
      lib.optionalAttrs (config.services.mdevd.enable || config.services.keventd.enable) {
        enableSystemd = false;
        udev = pkgs.libudev-zero;
      }
    )).overrideAttrs
      (o: {
        patches =
          o.patches or [ ]
          ++ lib.optionals (config.services.mdevd.enable || config.services.keventd.enable) [
            ./pipewire.patch
          ];
      });

  # The package doesn't output to $out/lib/pipewire directly so that the
  # overlays can use the outputs to replace the originals in FHS environments.
  #
  # This doesn't work in general because of missing development information.
  jack-libs = pkgs.runCommand "jack-libs" { } ''
    mkdir -p "$out/lib"
    ln -s "${cfg.package.jack}/lib" "$out/lib/pipewire"
  '';
in
{
  imports = [ ./test.nix ];

  options.programs.pipewire = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [pipewire](${pkgs.pipewire.meta.homepage}).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pipewire';
      defaultText = lib.literalExpression "pkgs.pipewire";
      description = ''
        The package to use for `pipewire`.
      '';
    };

    settings = lib.mkOption {
      type = format.type;
      default = { };
      example = {
        "context.properties" = {
          "default.clock.rate" = 44100;
        };
        "stream.properties" = {
          "channelmix.upmix" = false;
        };
      };
      description = ''
        `pipewire` configuration. See {manpage}`pipewire.conf(5)`
        for additional details.

        # https://man.archlinux.org/man/pipewire.conf.5
      '';
    };

    alsa = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable `ALSA` support.
        '';
      };

      support32Bit = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable 32-bit `ALSA` support on 64-bit systems.
        '';
      };
    };

    jack = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Whether to enable `JACK` support.
        '';
      };

      settings = lib.mkOption {
        type = format.type;
        default = { };
        example = {
          "jack.properties" = {
            "jack.show-midi" = false;
          };
        };
        description = ''
          `JACK` configuration. See {manpage}`pipewire-jack.conf(5)`
          for additional details.

          # https://man.archlinux.org/man/extra/pipewire-jack/pipewire-jack.conf.5
        '';
      };
    };

    client = {
      settings = lib.mkOption {
        type = format.type;
        default = { };
        example = {
          "stream.properties" = {
            "resample.disable" = true;
          };
        };
        description = ''
          `pipewire` client configuration. See {manpage}`pipewire-client.conf(5)`
          for additional details.

          # https://man.archlinux.org/man/extra/pipewire/pipewire-client.conf.5
        '';
      };
    };

    pulse = {
      settings = lib.mkOption {
        type = format.type;
        default = { };
        example = {
          "pulse.rules" = [
            {
              matches = [
                { "application.process.binary" = "my-broken-app"; }
              ];
              actions = {
                quirks = [ "force-s16-info" ];
              };
            }
          ];
        };
        description = ''
          `pulseaudio` server configuration. See {manpage}`pipewire-pulse.conf(5)`
          for additional details.

          # https://man.archlinux.org/man/pipewire-pulse.conf.5
        '';
      };
    };

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression ''
        [
          (pkgs.writeTextDir "share/pipewire/pipewire.conf.d/10-loopback.conf" '''
            context.modules = [
              { name = libpipewire-module-loopback
                args = { node.description = "Virtual source" }
              }
            ]
          ''')
        ]'';
      description = ''
        List of packages that provide `pipewire` configuration as
        `share/pipewire/<location>.conf.d/*.conf` files (for example loopback
        devices or filter chains).

        Their drop-ins are merged into `/etc/pipewire/<location>.conf.d`,
        alongside the drop-ins generated from {option}`programs.pipewire.settings`
        and friends.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package
    ]
    ++ lib.optionals cfg.jack.enable [ jack-libs ];

    services.udev.packages = [ cfg.package ];
    services.mdevd.hotplugRules = ''
      snd/.*  root:audio 0660
    '';

    environment.etc = {
      "security/limits.conf".text = ''
        @audio   -   rtprio     95
        @audio   -   nice       -19
        @audio   -   memlock    4194304
      '';

      "pipewire".source = "${configDir}";
    }
    // lib.optionalAttrs cfg.alsa.enable {
      "alsa/conf.d/49-pipewire-modules.conf" = {
        text = ''
          pcm_type.pipewire {
            libs.native = ${cfg.package}/lib/alsa-lib/libasound_module_pcm_pipewire.so ;
            ${lib.optionalString enable32BitAlsaPlugins "libs.32Bit = ${pipewire32'}/lib/alsa-lib/libasound_module_pcm_pipewire.so ;"}
          }
          ctl_type.pipewire {
            libs.native = ${cfg.package}/lib/alsa-lib/libasound_module_ctl_pipewire.so ;
            ${lib.optionalString enable32BitAlsaPlugins "libs.32Bit = ${pipewire32'}/lib/alsa-lib/libasound_module_ctl_pipewire.so ;"}
          }
        '';
      };

      "alsa/conf.d/50-pipewire.conf".source = "${cfg.package}/share/alsa/alsa.conf.d/50-pipewire.conf";
      "alsa/conf.d/99-pipewire-default.conf".source =
        "${cfg.package}/share/alsa/alsa.conf.d/99-pipewire-default.conf";
    };

    security.pam.environment = {
      LD_LIBRARY_PATH.default = lib.mkIf cfg.jack.enable [ "${cfg.package.jack}/lib" ];
    };
  };
}
