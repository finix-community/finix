{ config, lib, pkgs, ... }:

let
  inherit (builtins) readFile;
  inherit (lib)
    getExe
    mkIf
    mkEnableOption
    mkOption
    mkPackageOption
    types
    ;
  cfg = config.services.nix-actor;
in
{
  options = {
    services.nix-actor = {
      enable = mkEnableOption "the Nix Syndicate actor";
      package = mkPackageOption pkgs [ "sampkgs" "nix-actor" ] { };
    };
  };
  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = config.boot.serviceManager == "synit";
        message = "The nix-actor is only supported with the Synit service-manager.";
      }
    ];

    services.nix-daemon.enable = true;

    synit.daemons.nix-actor = {
      argv = [ "nix-actor" ];
      path = [ cfg.package config.services.nix-daemon.package ];
      protocol = "application/syndicate";
      requires = [
        { key = [ "daemon" "nix-daemon" ]; state = "ready"; }
      ];
      provides = lib.mkForce [ ];
    };

    synit.plan.config.nix-actor = [ (readFile ./nix-actor.pr) ];
  };
}
