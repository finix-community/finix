{
  pkgs,
  lib,
  config,
  ...
}:

with lib;
let
  inherit (lib.attrsets)
    attrsToList
    concatMapAttrs
    ;
  inherit (lib.lists)
    optional
    optionals
    ;
  inherit (lib.modules)
    mkIf
    ;
  inherit (lib.options)
    literalExpression
    mkEnableOption
    mkOption
    ;
  inherit (lib.strings)
    concatMapStringsSep
    optionalString
    ;
  inherit (lib.types)
    attrsOf
    listOf
    package
    ;

  cfg = config.programs.pipewire;

  json = pkgs.formats.json { };
  mapToFiles =
    location: config:
    concatMapAttrs (name: value: {
      "share/pipewire/${location}.conf.d/${name}.conf" = json.generate "${name}" value;
    }) config;
  extraConfigPkgFromFiles =
    locations: filesSet:
    pkgs.runCommand "pipewire-extra-config" { } ''
      mkdir -p ${concatMapStringsSep " " (l: "$out/share/pipewire/${l}.conf.d") locations}
      ${concatMapStringsSep ";" ({ name, value }: "ln -s ${value} $out/${name}") (attrsToList filesSet)}
    '';
  enable32BitAlsaPlugins =
    cfg.alsa.support32Bit && pkgs.stdenv.hostPlatform.isx86_64 && pkgs.pkgsi686Linux.pipewire != null;

  pipewire' =
    (pkgs.pipewire.override (
      lib.optionalAttrs config.services.mdevd.enable {
        enableSystemd = false;
        udev = pkgs.libudev-zero;
      }
    )).overrideAttrs
      (o: {
        # https://gitlab.freedesktop.org/pipewire/pipewire/-/issues/2398#note_2967898
        patches = o.patches or [ ] ++ lib.optionals config.services.mdevd.enable [ ./pipewire.patch ];
      });

  pipewire32' =
    (pkgs.pkgsi686Linux.pipewire.override (
      lib.optionalAttrs config.services.mdevd.enable {
        enableSystemd = false;
        udev = pkgs.libudev-zero;
      }
    )).overrideAttrs
      (o: {
        patches = o.patches or [ ] ++ lib.optionals config.services.mdevd.enable [ ./pipewire.patch ];
      });

  # The package doesn't output to $out/lib/pipewire directly so that the
  # overlays can use the outputs to replace the originals in FHS environments.
  #
  # This doesn't work in general because of missing development information.
  jack-libs = pkgs.runCommand "jack-libs" { } ''
    mkdir -p "$out/lib"
    ln -s "${cfg.package.jack}/lib" "$out/lib/pipewire"
  '';

  configPackages = cfg.configPackages;

  extraConfigPkg = extraConfigPkgFromFiles [ "pipewire" "client" "jack" "pipewire-pulse" ] (
    mapToFiles "pipewire" cfg.extraConfig.pipewire
    // mapToFiles "client" cfg.extraConfig.client
    // mapToFiles "jack" cfg.extraConfig.jack
    // mapToFiles "pipewire-pulse" cfg.extraConfig.pipewire-pulse
  );

  configs = pkgs.buildEnv {
    name = "pipewire-configs";
    paths =
      configPackages
      ++ [ extraConfigPkg ]
      ++ optionals cfg.wireplumber.enable cfg.wireplumber.configPackages;
    pathsToLink = [ "/share/pipewire" ];
  };

  requiredLv2Packages = flatten (
    concatMap (p: attrByPath [ "passthru" "requiredLv2Packages" ] [ ] p) configPackages
  );

  lv2Plugins = pkgs.buildEnv {
    name = "pipewire-lv2-plugins";
    paths = cfg.extraLv2Packages ++ requiredLv2Packages;
    pathsToLink = [ "/lib/lv2" ];
  };

  requiredLadspaPackages = flatten (
    concatMap (p: attrByPath [ "passthru" "requiredLadspaPackages" ] [ ] p) configPackages
  );

  ladspaPlugins = pkgs.buildEnv {
    name = "pipewire-ladspa-plugins";
    paths = cfg.extraLadspaPackages ++ requiredLadspaPackages;
    pathsToLink = [ "/lib/ladspa" ];
  };

in
{
  options.programs.pipewire = {
    enable = mkEnableOption "A low-level server and multimedia framework for handling audio and video streams";

    package = mkOption {
      type = package;
      default = pipewire';
      defaultText = "pkgs.pipewire";
      description = "The Pipewire package to use.";
    };

    alsa = {
      enable = mkEnableOption "PipeWire-ALSA support";
      support32Bit = mkEnableOption "32-bit ALSA support on 64-bit systems";
    };

    jack = {
      enable = mkEnableOption "JACK audio emulation";
    };

    # TODO need networking.firewall to properly port over nixos/pipewire rapOpenFirewall option

    extraConfig = {
      pipewire = mkOption {
        type = attrsOf json.type;
        default = { };
        example = {
          "10-clock-rate" = {
            "context.properties" = {
              "default.clock.rate" = 44100;
            };
          };
          "11-no-upmixing" = {
            "stream.properties" = {
              "channelmix.upmix" = false;
            };
          };
        };
        description = ''
          Additional configuration for the PipeWire server.

          Every item in this attrset becomes a separate drop-in file in `/etc/pipewire/pipewire.conf.d`.

          See `man pipewire.conf` for details, and [the PipeWire wiki][wiki] for examples.

          See also:
          - [PipeWire wiki - virtual devices][wiki-virtual-device] for creating virtual devices or remapping channels
          - [PipeWire wiki - filter-chain][wiki-filter-chain] for creating more complex processing pipelines
          - [PipeWire wiki - network][wiki-network] for streaming audio over a network

          [wiki]: https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/Config-PipeWire
          [wiki-virtual-device]: https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/Virtual-Devices
          [wiki-filter-chain]: https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/Filter-Chain
          [wiki-network]: https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/Network
        '';
      };
      client = mkOption {
        type = attrsOf json.type;
        default = { };
        example = {
          "10-no-resample" = {
            "stream.properties" = {
              "resample.disable" = true;
            };
          };
        };
        description = ''
          Additional configuration for the PipeWire client library, used by most applications.

          Every item in this attrset becomes a separate drop-in file in `/etc/pipewire/client.conf.d`.

          See the [PipeWire wiki][wiki] for examples.

          [wiki]: https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/Config-client
        '';
      };
      jack = mkOption {
        type = attrsOf json.type;
        default = { };
        example = {
          "20-hide-midi" = {
            "jack.properties" = {
              "jack.show-midi" = false;
            };
          };
        };
        description = ''
          Additional configuration for the PipeWire JACK server and client library.

          Every item in this attrset becomes a separate drop-in file in `/etc/pipewire/jack.conf.d`.

          See the [PipeWire wiki][wiki] for examples.

          [wiki]: https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/Config-JACK
        '';
      };
      pipewire-pulse = mkOption {
        type = attrsOf json.type;
        default = { };
        example = {
          "15-force-s16-info" = {
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
        };
        description = ''
          Additional configuration for the PipeWire PulseAudio server.

          Every item in this attrset becomes a separate drop-in file in `/etc/pipewire/pipewire-pulse.conf.d`.

          See `man pipewire-pulse.conf` for details, and [the PipeWire wiki][wiki] for examples.

          See also:
          - [PipeWire wiki - PulseAudio tricks guide][wiki-tricks] for more examples.

          [wiki]: https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/Config-PulseAudio
          [wiki-tricks]: https://gitlab.freedesktop.org/pipewire/pipewire/-/wikis/Guide-PulseAudio-Tricks
        '';
      };
    };

    configPackages = mkOption {
      type = listOf package;
      default = [ ];
      example = literalExpression ''
        [
                  (pkgs.writeTextDir "share/pipewire/pipewire.conf.d/10-loopback.conf" '''
                    context.modules = [
                    {   name = libpipewire-module-loopback
                        args = {
                          node.description = "Scarlett Focusrite Line 1"
                          capture.props = {
                              audio.position = [ FL ]
                              stream.dont-remix = true
                              node.target = "alsa_input.usb-Focusrite_Scarlett_Solo_USB_Y7ZD17C24495BC-00.analog-stereo"
                              node.passive = true
                          }
                          playback.props = {
                              node.name = "SF_mono_in_1"
                              media.class = "Audio/Source"
                              audio.position = [ MONO ]
                          }
                        }
                    }
                    ]
                  ''')
                ]'';
      description = ''
        List of packages that provide PipeWire configuration, in the form of
        `share/pipewire/*/*.conf` files.

        LV2/LADSPA dependencies will be picked up from config packages automatically
        via `passthru.requiredLv2Packages`/`passthru.requiredLadspaPackages`.
      '';
    };

    extraLv2Packages = mkOption {
      type = listOf package;
      default = [ ];
      example = literalExpression "[ pkgs.lsp-plugins ]";
      description = ''
        List of packages that provide LV2 plugins in `lib/lv2` that should
        be made available to PipeWire for [filter chains][wiki-filter-chain].

        Config packages have their required LV2 plugins added automatically,
        so they don't need to be specified here. Config packages need to set
        `passthru.requiredLv2Packages` for this to work.

        [wiki-filter-chain]: https://docs.pipewire.org/page_module_filter_chain.html
      '';
    };

    extraLadspaPackages = mkOption {
      type = listOf package;
      default = [ ];
      example = literalExpression "[ pkgs.noisetorch-ladspa ]";
      description = ''
        List of packages that provide LADSPA plugins in `lib/ladspa` that should
        be made available to PipeWire for [filter chains][wiki-filter-chain].

        Config packages have their required LADSPA plugins added automatically,
        so they don't need to be specified here. Config packages need to set
        `passthru.requiredLadspaPackages` for this to work.

        [wiki-filter-chain]: https://docs.pipewire.org/page_module_filter_chain.html
      '';
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [
      cfg.package

      # ??? see 378
      ladspaPlugins
      lv2Plugins
    ]
    ++ optional cfg.jack.enable jack-libs;

    services.udev.packages = mkIf config.services.udev.enable [ cfg.package ];
    services.mdevd.hotplugRules = mkIf (config.services.mdevd.enable && cfg.alsa.enable) (
      lib.mkAfter ''
        # alsa sound devices and audio stuff
        pcm.*       root:audio 0660 =snd/
        control.*   root:audio 0660 =snd/
        midi.*      root:audio 0660 =snd/
        seq         root:audio 0660 =snd/
        timer       root:audio 0660 =snd/

        adsp        root:audio 0660 >sound/
        audio       root:audio 0660 >sound/
        dsp         root:audio 0660 >sound/
        mixer       root:audio 0660 >sound/
        sequencer.* root:audio 0660 >sound/
      ''
    );

    environment.etc."security/limits.conf".text = ''
      @audio   -   rtprio     95
      @audio   -   nice       -19
      @audio   -   memlock    4194304
    '';
    environment.etc = {
      "alsa/conf.d/49-pipewire-modules.conf" = mkIf cfg.alsa.enable {
        text = ''
          pcm_type.pipewire {
            libs.native = ${cfg.package}/lib/alsa-lib/libasound_module_pcm_pipewire.so ;
            ${optionalString enable32BitAlsaPlugins "libs.32Bit = ${pipewire32'}/lib/alsa-lib/libasound_module_pcm_pipewire.so ;"}
          }
          ctl_type.pipewire {
            libs.native = ${cfg.package}/lib/alsa-lib/libasound_module_ctl_pipewire.so ;
            ${optionalString enable32BitAlsaPlugins "libs.32Bit = ${pipewire32'}/lib/alsa-lib/libasound_module_ctl_pipewire.so ;"}
          }
        '';
      };

      "alsa/conf.d/50-pipewire.conf" = mkIf cfg.alsa.enable {
        source = "${cfg.package}/share/alsa/alsa.conf.d/50-pipewire.conf";
      };

      "alsa/conf.d/99-pipewire-default.conf" = mkIf cfg.alsa.enable {
        source = "${cfg.package}/share/alsa/alsa.conf.d/99-pipewire-default.conf";
      };
      pipewire.source = "${configs}/share/pipewire";
    };

    security.pam.environment = {
      LD_LIBRARY_PATH.default = mkIf cfg.jack.enable [ "${cfg.package.jack}/lib" ];
      LV2_PATH.default = [ "${lv2Plugins}/lib/lv2" ];
      LADSPA_PATH.default = [ "${ladspaPlugins}/lib/ladspa" ];
    };
  };
}
