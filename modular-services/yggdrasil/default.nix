defaultPackage:

{ config, lib, pkgs, ... }:

let
  inherit (lib)
    attrValues
    makeBinPath
    mkOption
     literalExample
    optionalString
    types
   ;

  writeExeclineScript = pkgs.execline.passthru.writeScript;

  keysPath = "/var/lib/yggdrasil/keys.json";

  cfg = config.yggdrasil;
  settingsProvided = cfg.settings != { };
  configFileProvided = cfg.configFile != null;

  format = pkgs.formats.json { };

  # This script first prepares the config file then it starts Yggdrasil.
  configScript = writeExeclineScript "yggdrasil-config.el" "-S0" ''
    export PATH ${makeBinPath (attrValues {
        inherit (cfg) package;
        inherit (pkgs)
          execline
          hjson-go
          jq
          kmod
          s6-portable-utils
          ;
      })}

    fdmove -c 1 2

    # Initialise /dev/net/tun.
    foreground { modprobe tun }

    # Prepare config file.
    if { s6-mkdir -m 700 -p /run/yggdrasil }
    pipeline -d -r {
      pipeline -r {

    ${optionalString settingsProvided ''
      if { s6-echo ${builtins.toJSON (builtins.toJSON cfg.settings)} }
    ''}${optionalString configFileProvided ''
      if { hjson-cli -c "${cfg.configFile}"
    ''}${optionalString cfg.persistentKeys ''
      if {
        foreground {
          if -n { eltest -s ${keysPath} }
          if { s6-mkdir -m 700 -p ${builtins.dirOf keysPath} }
          pipeline -r { yggdrasil -genconf -json }
          redirfd -w 1 ${keysPath}
          jq "to_entries|map(select(.key|endswith(\"Key\")))|from_entries"
        }
        cat ${keysPath}
      }
    ''}${
      optionalString (!(settingsProvided || configFileProvided || cfg.persistentKeys)) ''
        if { yggdrasil -genconf -json }
      ''
    }
        exit
      }

      jq --slurp add
    }

    # Exec into yggdrasil.
    emptyenv -c
    $@
  '';

in
{
  _class = "service";

  options.yggdrasil = {

      settings = mkOption {
        type = format.type;
        default = { };
        example = {
          Peers = [
            "tcp://aa.bb.cc.dd:eeeee"
            "tcp://[aaaa:bbbb:cccc:dddd::eeee]:fffff"
          ];
          Listen = [
            "tcp://0.0.0.0:xxxxx"
          ];
        };
        description = ''
          Configuration for yggdrasil, as a Nix attribute set.

          Warning: this is stored in the WORLD-READABLE Nix store!
          Therefore, it is not appropriate for private keys. If you
          wish to specify the keys, use {option}`configFile`.

          If the {option}`persistentKeys` is enabled then the
          keys that are generated during activation will override
          those in {option}`settings` or
          {option}`configFile`.

          If no keys are specified then ephemeral keys are generated
          and the Yggdrasil interface will have a random IPv6 address
          each time the service is started. This is the default.

          If both {option}`configFile` and {option}`settings`
          are supplied, they will be combined, with values from
          {option}`configFile` taking precedence.

          You can use the command `nix-shell -p yggdrasil --run "yggdrasil -genconf"`
          to generate default configuration values with documentation.
        '';
      };

      configFile = mkOption {
        type = with types; nullOr path;
        default = null;
        example = "/run/keys/yggdrasil.conf";
        description = ''
          A file which contains JSON or HJSON configuration for yggdrasil. See
          the {option}`settings` option for more information.
        '';
      };

      package = lib.mkOption { 
        type = types.package;
        default = defaultPackage;
        defaultText = literalExample "pkgs.yggdrasil";
      };

      persistentKeys = lib.mkEnableOption ''
        persistent keys. If enabled then keys will be generated once and Yggdrasil
        will retain the same IPv6 address when the service is
        restarted. Keys are stored at ${keysPath}
      '';

      extraArgs = mkOption {
        type = with types; listOf str;
        default = [ ];
        example = [
          "-loglevel"
          "info"
        ];
        description = "Extra command line arguments.";
      };

  };

  config = {
    process = {
      argv = [
        configScript
        "${cfg.package}/bin/yggdrasil" "-useconf"
      ] ++ cfg.extraArgs;
    };
  };

}
