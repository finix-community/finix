{ lib, config, pkgs, ... }:

let
  inherit (lib)
    getExe
    getExe'
    makeBinPath
    mkDefault
    mkEnableOption
    mkPackageOption
    mkIf
    mkOption
    optionals
    ;

  writeExeclineScript = pkgs.execline.passthru.writeScript;

  cfg = config.synit;

in
{
  imports = [
    ./daemons.nix
    ./dependencies.nix
    ./filesystems.nix
    ./logging.nix
    ./networking.nix
    ./profile.nix
  ];

  options.synit = {
    enable = mkOption {
      default = config.boot.serviceManager == "synit";
      defaultText = ''config.boot.serviceManager == "synit"'';
      readOnly = true;
    };

    logging = {
      logToFileSystem = mkEnableOption "logging to the file-system by default" // {
        default = true;
      };
    };

    syndicate-server.package = mkPackageOption pkgs "syndicate-server" { };

    pid1.package = mkPackageOption pkgs "synit-pid1" { };

  };

  config = mkIf cfg.enable {

    boot.init.pid1Argv = {
      # This tells Rust programs built with jemallocator to be very aggressive about keeping their
      # heaps small. Synit currently targets small machines. Without this, I have seen the system
      # syndicate-server take around 300MB of heap when doing not particularly much; with this, it
      # takes about 15MB in the same state. There is a performance penalty on being so aggressive
      # about heap size, but it's more important to stay small in this circumstance right now. - tonyg
      mallocConf = {
        text = mkDefault [
          (getExe' pkgs.execline "export")
          "_RJEM_MALLOC_CONF"
          "narenas:1,tcache:false,dirty_decay_ms:0,muzzy_decay_ms:0"
        ];
      };
      synit-pid1 = {
        deps = [ "mallocConf" ];
        text = mkDefault [ (getExe cfg.pid1.package) ];
      };
      path = {
        deps = [ "synit-pid1" ];
        text = mkDefault [
          (getExe' pkgs.execline "export")
          "PATH"
          (makeBinPath [
            pkgs.s6-portable-utils
          ])
        ];
      };
      logger = {
        deps = [ "path" ];
        text = mkDefault (optionals cfg.logging.logToFileSystem [
            (writeExeclineScript "logger.el" "-s1" ''
              if { s6-mkdir -p $1 }
              fdswap 1 2
              pipeline -w { ${getExe' pkgs.s6 "s6-log"} $1 }
              fdswap 1 2
              $@
            '')
          "/var/log/synit"
        ]);
      };
      syndicate-server = {
        deps = [ "logger" ];
        text = mkDefault [
          (getExe cfg.syndicate-server.package)
          "--inferior"
        ];
      };
      syndicate-server-config = {
        deps = [ "syndicate-server" ];
        text = mkDefault [
          "--config" "${./boot.pr}"
        ];
      };
    };

    environment.systemPackages = [
      cfg.syndicate-server.package
      pkgs.synit-service
    ];

    # Only tested with mdevd.
    services.mdevd.enable = mkDefault true;

    system.activation.scripts.synit-config = {
      deps = [ "specialfs" ];
      text = "install --mode=644 --directory /run/synit/config/{core,machine,network,profile}";
    };

  };

  meta = {
    maintainers = with lib.maintainers; [ ehmry ];
    # doc = ./todo.md;
  };
}
