{ lib, config, pkgs, ... }:

let
  inherit (lib)
    attrValues
    getExe
    getExe'
    mkDefault
    mkEnableOption
    mkPackageOption
    mkIf
    mkOption
    optionals
    quoteExecline
    ;

  writeExeclineScript = pkgs.execline.writeScript;

  cfg = config.synit;

  synitPackages = attrValues {
    inherit (pkgs) execline s6 s6-linux-utils s6-portable-utils;
    inherit (cfg.syndicate-server) package;
  };

in
{
  imports = [
    ./daemons.nix
    ./dependencies.nix
    ./filesystems.nix
    ./logging.nix
    ./networking.nix
    ./plans.nix
  ];

  options.synit = {
    enable = mkOption {
      default = config.boot.serviceManager == "synit";
      defaultText = ''config.boot.serviceManager == "synit"'';
      readOnly = true;
      description = ''
        Whether to enable [synit](${pkgs.synit-pid1.meta.homepage}) as the system service manager and pid `1`.
      '';
    };

    basePath = mkOption {
      description = "PATH used to boot the system bus.";
      readOnly = true;
      defaultText  = "The packages execline, s6, syndicate-server, and security wrappers.";
      default = "${pkgs.buildEnv {
            name = "synit-base-env";
            paths = synitPackages;
          }}/bin:${config.security.wrapperDir}";
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

    boot.init.pid1 = {
      env = {
        # This tells Rust programs built with jemallocator to be very aggressive about keeping their
        # heaps small. Synit currently targets small machines. Without this, I have seen the system
        # syndicate-server take around 300MB of heap when doing not particularly much; with this, it
        # takes about 15MB in the same state. There is a performance penalty on being so aggressive
        # about heap size, but it's more important to stay small in this circumstance right now. - tonyg
        "_RJEM_MALLOC_CONF" = "narenas:1,tcache:false,dirty_decay_ms:0,muzzy_decay_ms:0";
        PATH = cfg.basePath;
      };
      argv = {
        pid1 = {
          deps = [ "env" ];
          text = [
            (getExe cfg.pid1.package)
          ];
        };

        logger = {
          deps = [  "pid1" ];
          text = mkDefault (optionals cfg.logging.logToFileSystem (quoteExecline [
            "foreground" [ "s6-mkdir" "-p" "/var/log/system-bus" ]
            "fdswap" "1" "2"
            "pipeline" "-w" [ "s6-log" "/var/log/system-bus" ]
            "fdswap" "1" "2"
          ]));
        };

        # Activate as a child of PID 1.
        activation = {
          deps = [ "logger" "pid1" ];
          text = quoteExecline [
            "foreground" [
              # Stdio is reserved for syndicate-protocol.
              "fdclose" "0"
              "fdmove" "-c" "1" "2"
              "foreground" [
                # Run the activation script.
                "@systemConfig@/activate"
              ]
              # Start an actor responsible for the plan set by the activation script.
              "redirfd" "-w" "1" "/run/synit/config/plans/boot.pr"
              # The use dummy activation script because the real script already ran.
              "s6-echo" ''! <activate <plan "default" "${cfg.plan.file}" [ "s6-true" ]>>''
            ]
          ];
        };

        syndicate-server = {
          deps = [ "activation" "logger" ];
          text = mkDefault [
            "syndicate-server"
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
    };

    environment.systemPackages = synitPackages ++ [
      pkgs.synit-service
    ];

    # Only tested with mdevd.
    services.mdevd.enable = mkDefault true;

    system.activation.scripts.synit-config = {
      deps = [ "specialfs" ];
      text = ''
        for D in /etc/syndicate/core /run/synit/{,config/{,core,machine,network,persistent,plans,state},locks}; do
          s6-mkdir -m 750 -p $D
          s6-chown -g 1 $D
        done
      '';
    };

  };

  meta = {
    maintainers = with lib.maintainers; [ ehmry ];
    # doc = ./todo.md;
  };
}
