{
  modules,
  config,
  options,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) types;
  cfg = config.services.amneziawg;
in
{
  imports = [ modules.wireguard ];

  options.services.wireguard.interfaces = lib.mkOption {
    type = types.attrsOf (
      types.submodule {
        options.extraOptions = lib.mkOption {
          type = types.submodule {
            options = {
              Jc = lib.mkOption {
                type = types.nullOr (types.ints.between 0 65535);
                default = null;
                description = "Number of junk packets.";
              };

              Jmin = lib.mkOption {
                type = types.nullOr (types.ints.between 0 65535);
                default = null;
                description = "Minimum junk packet size.";
              };

              Jmax = lib.mkOption {
                type = types.nullOr (types.ints.between 0 65535);
                default = null;
                description = "Maximum junk packet size.";
              };

              S1 = lib.mkOption {
                type = types.nullOr (types.ints.between 0 65535);
                default = null;
                description = "Handshake initiation padding.";
              };

              S2 = lib.mkOption {
                type = types.nullOr (types.ints.between 0 65535);
                default = null;
                description = "Handshake response padding.";
              };

              S3 = lib.mkOption {
                type = types.nullOr (types.ints.between 0 65535);
                default = null;
                description = "Cookie reply padding.";
              };

              S4 = lib.mkOption {
                type = types.nullOr (types.ints.between 0 65535);
                default = null;
                description = "Transport packet padding.";
              };

              H1 = lib.mkOption {
                type = types.nullOr types.singleLineStr;
                default = null;
                description = "Handshake initiation header identifier.";
              };

              H2 = lib.mkOption {
                type = types.nullOr types.singleLineStr;
                default = null;
                description = "Handshake response header identifier.";
              };

              H3 = lib.mkOption {
                type = types.nullOr types.singleLineStr;
                default = null;
                description = "Cookie reply header identifier.";
              };

              H4 = lib.mkOption {
                type = types.nullOr types.singleLineStr;
                default = null;
                description = "Transport packet header identifier.";
              };

              I1 = lib.mkOption {
                type = types.nullOr types.singleLineStr;
                default = null;
                description = "First custom packet description.";
              };

              I2 = lib.mkOption {
                type = types.nullOr types.singleLineStr;
                default = null;
                description = "Second custom packet description.";
              };

              I3 = lib.mkOption {
                type = types.nullOr types.singleLineStr;
                default = null;
                description = "Third custom packet description.";
              };

              I4 = lib.mkOption {
                type = types.nullOr types.singleLineStr;
                default = null;
                description = "Fourth custom packet description.";
              };

              I5 = lib.mkOption {
                type = types.nullOr types.singleLineStr;
                default = null;
                description = "Fifth custom packet description.";
              };
            };
          };
        };
      }
    );
  };

  options.services.amneziawg = {
    enable = lib.mkOption {
      description = ''
        Whether to enable AmneziaWG.
      '';
      type = types.bool;
      default = false;
      example = true;
    };

    interfaces = lib.mkOption {
      description = "AmneziaWG interfaces.";
      default = { };
      type = options.services.wireguard.interfaces.type;
    };
  };

  config = lib.mkIf cfg.enable {
    services.wireguard = {
      enable = true;
      package = pkgs.amneziawg-tools;
      kernelModule = "amneziawg";
      kernelModulePackage = config.boot.kernelPackages.amneziawg;
      inherit (cfg) interfaces;
    };
  };
}
