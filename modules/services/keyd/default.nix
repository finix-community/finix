{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.keyd;

  mkKeyValue = lib.generators.mkKeyValueDefault { } " = ";

  keyboardOpts = {
    options = {
      ids = lib.mkOption {
        type = with lib.types; listOf str;
        default = [ "" ];
        example = [
          "*"
          "-0123:0456"
        ];
        description = ''
          Device identifiers, as shown by {manpage}`keyd(1)`.
        '';
      };

      settings = lib.mkOption {
        type = (pkgs.formats.ini { }).type;
        default = { };
        example = {
          main = {
            capslock = "overload(control,esc)";
            rightalt = "layer(rightalt)";
          };

          rightalt = {
            j = "down";
            k = "up";
            h = "left";
            l = "right";
          };
        };

        description = ''
          Configuration, except `ids` section, that is written to {file}`/etc/keyd/<keyboard>.conf`.
          Appropriate names can be used to write non-alpha keys, for example "equal" instead of "=" sign (see <https://github.com/NixOS/nixpkgs/issues/236622>).
          See <https://github.com/rvaiya/keyd> for how to configure.
        '';
      };

      extraConfig = lib.mkOption {
        type = lib.types.lines;
        default = "";
        example = ''
          [control+shift]
          h = left
        '';
        description = ''
          Extra configuration that is appended to the end of the file.
          **Do not** write `ids` section here, use a separate option for it.
          You can use this option to define compound layers that must always be defined after the layer they are comprised.
        '';
      };
    };
  };
in
{
  options.services.keyd = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [keyd](${pkgs.keyd.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.keyd;
      defaultText = lib.literalExpression "pkgs.keyd";
      description = ''
        The package to use for `keyd`.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.
      '';
    };

    keyboards = lib.mkOption {
      type = with lib.types; attrsOf (submodule keyboardOpts);
      default = { };
      example = lib.literalExpression ''
        {
          default = {
            ids = [ "*" ];
            settings = {
              main = {
                capslock = "overload(control, esc)";
              };
            };
          };
          externalKeyboard = {
            ids = [ "1ea7:0907" ];
            settings = {
              main = {
                esc = capslock;
              };
            };
          };
        }
      '';
      description = ''
        `keyd` configuration. See {manpage}`keyd(1)`
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    hardware.uinput.enable = true;

    environment.etc =
      let
        configTree = lib.mapAttrs' (
          name: keyboardOpts:
          lib.nameValuePair "keyd/${name}.conf" {
            source = pkgs.writeText "${name}.conf" ''
              [ids]
              ${lib.concatStringsSep "\n" keyboardOpts.ids}

              ${lib.generators.toINI {
                inherit mkKeyValue;
              } keyboardOpts.settings}
              ${keyboardOpts.extraConfig}
            '';
          }
        ) cfg.keyboards;

        serviceFile = lib.mkIf (config.finit.enable && config.finit.services.keyd.enable) {
          # TODO: add finit.services.reloadTriggers option
          "finit.d/keyd.conf".text = lib.mkAfter ''

            # force a reload on configuration change
            ${lib.concatMapAttrsStringSep "\n" (k: v: "# " + v.source) configTree}
          '';
        };
      in
      lib.mkMerge [
        configTree
        serviceFile
      ];

    finit.services.keyd = {
      description = "keyd, a key remapping daemon";
      command = "${cfg.package}/bin/keyd";
      conditions = "service/syslogd/ready";
      reload = "${cfg.package}/bin/keyd reload";
      log = true;
      environment = lib.optionalAttrs cfg.debug { KEYD_DEBUG = 2; };
    };

    # used for group ownership of keyd socket
    users.groups.keyd = { };
  };
}
