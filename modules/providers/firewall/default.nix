{ config, lib, ... }:
let
  cfg = config.providers.firewall;

  portRange = lib.types.submodule {
    options = {
      from = lib.mkOption {
        type = lib.types.port;
        description = ''
          The first port of the range, inclusive.
        '';
      };

      to = lib.mkOption {
        type = lib.types.port;
        description = ''
          The last port of the range, inclusive.
        '';
      };
    };
  };
in
{
  options.providers.firewall = {
    backend = lib.mkOption {
      type = lib.types.enum [ "none" ];
      default = "none";
      description = ''
        The selected module which should implement functionality for the {option}`providers.firewall` contract.
      '';
    };

    allowedTCPPorts = lib.mkOption {
      type = with lib.types; listOf port;
      default = [ ];
      example = [
        22
        80
        443
      ];
      description = ''
        List of TCP ports on which incoming connections are accepted.
      '';
    };

    allowedTCPPortRanges = lib.mkOption {
      type = lib.types.listOf portRange;
      default = [ ];
      example = [
        {
          from = 8999;
          to = 9003;
        }
      ];
      description = ''
        A range of TCP ports on which incoming connections are accepted.
      '';
    };

    allowedUDPPorts = lib.mkOption {
      type = with lib.types; listOf port;
      default = [ ];
      example = [ 53 ];
      description = ''
        List of open UDP ports.
      '';
    };

    allowedUDPPortRanges = lib.mkOption {
      type = lib.types.listOf portRange;
      default = [ ];
      example = [
        {
          from = 60000;
          to = 61000;
        }
      ];
      description = ''
        Range of open UDP ports.
      '';
    };
  };

  config.warnings =
    let
      openPorts =
        cfg.allowedTCPPorts ++ cfg.allowedTCPPortRanges ++ cfg.allowedUDPPorts ++ cfg.allowedUDPPortRanges;
    in
    lib.optionals (openPorts != [ ] && cfg.backend == "none") [
      ''
        no firewall provider backend has been enabled, yet ports are requested to be opened
        select a backend implementation to use the firewall
      ''
    ];
}
