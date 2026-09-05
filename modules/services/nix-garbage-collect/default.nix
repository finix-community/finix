{
  config,
  lib,
  ...
}:
let
  cfg = config.services.nix-garbage-collect;
in
{
  options.services.nix-garbage-collect = {
    enable = lib.mkEnableOption "Whether to enable an automatic garbage collection service";
    backend = lib.mkOption {
      type = lib.types.enum [
        "none"
        "nix-collect-garbage"
        "nix store"
        "nix-store"
      ];
      default = "none";
      description = ''
        The backend to use for automatic garbage collection, has no function if `services.nix-garbage-collect.command` has a value value that does not contain `cfg.backend`.
      '';
    };
    command = lib.mkOption {
      type = lib.types.str;
      default = cfg.backend;
      description = ''
        The command for the service to issue
      '';
    };
    interval = lib.mkOption {
      type = lib.types.singleLineStr;
      default = "weekly";
      description = ''
        How often cleanup is performed. Passed to `providers.scheduler.tasks.nix-garbage-collect`
      '';
    };
    extraArgs = lib.mkOption {
      type = lib.types.singleLineStr;
      default = "";
      example = "--keep 5 --keep-since 3d";
      description = ''
        Options given to backend when the service is run automatically.

        For nix-collect-garbage see `nix-collect-garbage --help`
        For nix-store see `nix-store --help`
        For nix store see `nix store --help`
        Additional:
        For nh see `nh clean all --help`
        For nixos-cli see `nixos generations delete --help`, additionally for nixos-cli no backend is provided you must use `cfg.command`
      '';
    };
  };

  config = {
    assertions = [
      {
        assertion =
          (cfg.enable == true) && ((cfg.backend == "none") -> !(lib.hasInfix cfg.backend cfg.command));
        message = "Backend is none but command calls for a backend";
      }
    ];

    providers.scheduler.tasks.nix-garbage-collect = lib.mkIf cfg.enable {
      command =
        if cfg.command != cfg.backend then
          "${cfg.command} ${cfg.extraArgs}"
        else if cfg.backend == "nix-collect-garbage" then
          "${cfg.command} ${cfg.extraArgs}"
        else if cfg.backend == "nix-store" then
          "${cfg.command} --gc ${cfg.extraArgs}"
        else
          "${cfg.command} gc ${cfg.extraArgs}";
      interval = cfg.interval;
    };
  };
}
