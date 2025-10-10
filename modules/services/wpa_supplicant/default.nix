{ config, lib, options, pkgs, ... }:

with lib;

let
  cfg = config.networking.wireless // config.services.wpa_supplicant;
  opt = options.networking.wireless;

  wpa3Protocols = [
    "SAE"
    "FT-SAE"
  ];
  hasMixedWPA =
    opts:
    let
      hasWPA3 = !mutuallyExclusive opts.authProtocols wpa3Protocols;
      others = subtractLists wpa3Protocols opts.authProtocols;
    in
    hasWPA3 && others != [ ];

  # Gives a WPA3 network higher priority
  increaseWPA3Priority =
    opts:
    opts
    // optionalAttrs (hasMixedWPA opts) {
      priority = if opts.priority == null then 1 else opts.priority + 1;
    };

  # Creates a WPA2 fallback network
  mkWPA2Fallback = opts: opts // { authProtocols = subtractLists wpa3Protocols opts.authProtocols; };

  # Networks attrset as a list
  networkList = mapAttrsToList (ssid: opts: opts // { inherit ssid; }) cfg.networks;

  # List of all networks (normal + generated fallbacks)
  allNetworks =
    if cfg.fallbackToWPA2 then
      map increaseWPA3Priority networkList ++ map mkWPA2Fallback (filter hasMixedWPA networkList)
    else
      networkList;

  # Content of wpa_supplicant.conf
  generatedConfig = concatStringsSep "\n" (
    (map mkNetwork allNetworks)
    ++ optional cfg.userControlled.enable (
      concatStringsSep "\n" [
        "ctrl_interface=/run/wpa_supplicant"
        "ctrl_interface_group=${cfg.userControlled.group}"
        "update_config=1"
      ]
    )
    ++ [ "pmf=1" ]
    ++ optional (cfg.secretsFile != null) "ext_password_backend=file:${cfg.secretsFile}"
    ++ optional cfg.scanOnLowSignal ''bgscan="simple:30:-70:3600"''
    ++ optional (cfg.extraConfig != "") cfg.extraConfig
  );

  configIsGenerated = with cfg; networks != { } || extraConfig != "" || userControlled.enable;

  # the original configuration file
  configFile =
    if configIsGenerated then
      pkgs.writeText "wpa_supplicant.conf" generatedConfig
    else
      "/etc/wpa_supplicant.conf";

  # Creates a network block for wpa_supplicant.conf
  mkNetwork =
    opts:
    let
      quote = x: ''"${x}"'';
      indent = x: "  " + x;

      pskString = if opts.psk != null then quote opts.psk else opts.pskRaw;

      options =
        [
          "ssid=${quote opts.ssid}"
          (
            if pskString != null || opts.auth != null then
              "key_mgmt=${concatStringsSep " " opts.authProtocols}"
            else
              "key_mgmt=NONE"
          )
        ]
        ++ optional opts.hidden "scan_ssid=1"
        ++ optional (pskString != null) "psk=${pskString}"
        ++ optionals (opts.auth != null) (filter (x: x != "") (splitString "\n" opts.auth))
        ++ optional (opts.priority != null) "priority=${toString opts.priority}"
        ++ filter (x: x != "") (splitString "\n" opts.extraConfig);
    in
    ''
      network={
      ${concatMapStringsSep "\n" indent options}
      }
    '';

in
{
  options = {
    networking.wireless = {
      networks = mkOption {
        type = types.attrsOf (
          types.submodule {
            options = {
              psk = mkOption {
                type = types.nullOr (types.strMatching "[[:print:]]{8,63}");
                default = null;
                description = ''
                  The network's pre-shared key in plaintext defaulting
                  to being a network without any authentication.

                  ::: {.warning}
                  Be aware that this will be written to the Nix store
                  in plaintext! Use {var}`pskRaw` with an external
                  reference to keep it safe.
                  :::

                  ::: {.note}
                  Mutually exclusive with {var}`pskRaw`.
                  :::
                '';
              };

              pskRaw = mkOption {
                type = types.nullOr (types.strMatching "([[:xdigit:]]{64})|(ext:[^=]+)");
                default = null;
                example = "ext:name_of_the_secret_here";
                description = ''
                  Either the raw pre-shared key in hexadecimal format
                  or the name of the secret (as defined inside
                  [](#opt-networking.wireless.secretsFile) and prefixed
                  with `ext:`) containing the network pre-shared key.

                  ::: {.warning}
                  Be aware that this will be written to the Nix store
                  in plaintext! Always use an external reference.
                  :::

                  ::: {.note}
                  The external secret can be either the plaintext
                  passphrase or the raw pre-shared key.
                  :::

                  ::: {.note}
                  Mutually exclusive with {var}`psk` and {var}`auth`.
                  :::
                '';
              };

              authProtocols = mkOption {
                default = [
                  # WPA2 and WPA3
                  "WPA-PSK"
                  "WPA-EAP"
                  "SAE"
                  # 802.11r variants of the above
                  "FT-PSK"
                  "FT-EAP"
                  "FT-SAE"
                ];
                # The list can be obtained by running this command
                # awk '
                #   /^# key_mgmt: /{ run=1 }
                #   /^#$/{ run=0 }
                #   /^# [A-Z0-9-]{2,}/{ if(run){printf("\"%s\"\n", $2)} }
                # ' /run/current-system/sw/share/doc/wpa_supplicant/wpa_supplicant.conf.example
                type = types.listOf (
                  types.enum [
                    "WPA-PSK"
                    "WPA-EAP"
                    "IEEE8021X"
                    "NONE"
                    "WPA-NONE"
                    "FT-PSK"
                    "FT-EAP"
                    "FT-EAP-SHA384"
                    "WPA-PSK-SHA256"
                    "WPA-EAP-SHA256"
                    "SAE"
                    "FT-SAE"
                    "WPA-EAP-SUITE-B"
                    "WPA-EAP-SUITE-B-192"
                    "OSEN"
                    "FILS-SHA256"
                    "FILS-SHA384"
                    "FT-FILS-SHA256"
                    "FT-FILS-SHA384"
                    "OWE"
                    "DPP"
                  ]
                );
                description = ''
                  The list of authentication protocols accepted by this network.
                  This corresponds to the `key_mgmt` option in wpa_supplicant.
                '';
              };

              auth = mkOption {
                type = types.nullOr types.str;
                default = null;
                example = ''
                  eap=PEAP
                  identity="user@example.com"
                  password=ext:example_password
                '';
                description = ''
                  Use this option to configure advanced authentication methods
                  like EAP. See {manpage}`wpa_supplicant.conf(5)` for example
                  configurations.

                  ::: {.warning}
                  Be aware that this will be written to the Nix store
                  in plaintext! Use an external reference like
                  `ext:secretname` for secrets.
                  :::

                  ::: {.note}
                  Mutually exclusive with {var}`psk` and {var}`pskRaw`.
                  :::
                '';
              };

              hidden = mkOption {
                type = types.bool;
                default = false;
                description = ''
                  Set this to `true` if the SSID of the network is hidden.
                '';
                example = literalExpression ''
                  { echelon = {
                      hidden = true;
                      psk = "abcdefgh";
                    };
                  }
                '';
              };

              priority = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = ''
                  By default, all networks will get same priority group (0). If
                  some of the networks are more desirable, this field can be used
                  to change the order in which wpa_supplicant goes through the
                  networks when selecting a BSS. The priority groups will be
                  iterated in decreasing priority (i.e., the larger the priority
                  value, the sooner the network is matched against the scan
                  results). Within each priority group, networks will be selected
                  based on security policy, signal strength, etc.
                '';
              };

              extraConfig = mkOption {
                type = types.str;
                default = "";
                example = ''
                  bssid_blacklist=02:11:22:33:44:55 02:22:aa:44:55:66
                '';
                description = ''
                  Extra configuration lines appended to the network block.
                  See {manpage}`wpa_supplicant.conf(5)` for available options.
                '';
              };

            };
          }
        );
        description = ''
          The network definitions to automatically connect to when
           {command}`wpa_supplicant` is running. If this
           parameter is left empty wpa_supplicant will use
          /etc/wpa_supplicant.conf as the configuration file.
        '';
        default = { };
        example = literalExpression ''
          { echelon = {                   # SSID with no spaces or special characters
              psk = "abcdefgh";           # (password will be written to /nix/store!)
            };

            echelon = {                   # safe version of the above: read PSK from the
              pskRaw = "ext:psk_echelon"; # variable psk_echelon, defined in secretsFile,
            };                            # this won't leak into /nix/store

            "echelon's AP" = {            # SSID with spaces and/or special characters
               psk = "ijklmnop";          # (password will be written to /nix/store!)
            };

            "free.wifi" = {};             # Public wireless network
          }
        '';
      };
    };

    services.wpa_supplicant = {
      enable = mkEnableOption "wpa_supplicant";

      interfaces = mkOption {
        type = types.listOf types.str;
        example = [
          "wlan0"
          "wlan1"
        ];
        default = [ ];
        description = ''
          The interfaces {command}`wpa_supplicant` will use. If empty, it will
          automatically use all wireless interfaces.

          ::: {.note}
          A separate wpa_supplicant instance will be started for each interface.
          :::
        '';
      };

      driver = mkOption {
        type = types.str;
        default = "nl80211,wext";
        description = "Force a specific wpa_supplicant driver.";
      };

      allowAuxiliaryImperativeNetworks =
        mkEnableOption "support for imperative & declarative networks"
        // {
          description = ''
            Whether to allow configuring networks "imperatively" (e.g. via
            `wpa_supplicant_gui`) and declaratively via
            [](#opt-networking.wireless.networks).
          '';
        };

      scanOnLowSignal = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether to periodically scan for (better) networks when the signal of
          the current one is low. This will make roaming between access points
          faster, but will consume more power.
        '';
      };

      fallbackToWPA2 = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether to fall back to WPA2 authentication protocols if WPA3 failed.
          This allows old wireless cards (that lack recent features required by
          WPA3) to connect to mixed WPA2/WPA3 access points.

          To avoid possible downgrade attacks, disable this options.
        '';
      };

      secretsFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/run/secrets/wireless.conf";
        description = ''
          File consisting of lines of the form `varname=value`
          to define variables for the wireless configuration.

          Secrets (PSKs, passwords, etc.) can be provided without adding them to
          the world-readable Nix store by defining them in the secrets file and
          referring to them in option [](#opt-networking.wireless.networks)
          with the syntax `ext:secretname`. Example:

          ```
          # content of /run/secrets/wireless.conf
          psk_home=mypassword
          psk_other=6a381cea59c7a2d6b30736ba0e6f397f7564a044bcdb7a327a1d16a1ed91b327
          pass_work=myworkpassword

          # wireless-related configuration
          networking.wireless.secretsFile = "/run/secrets/wireless.conf";
          networking.wireless.networks = {
            home.pskRaw = "ext:psk_home";
            other.pskRaw = "ext:psk_other";
            work.auth = '''
              eap=PEAP
              identity="my-user@example.com"
              password=ext:pass_work
            ''';
          };
          ```
        '';
      };

      userControlled = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Allow normal users to control wpa_supplicant through wpa_gui or wpa_cli.
            This is useful for laptop users that switch networks a lot and don't want
            to depend on a large package such as NetworkManager just to pick nearby
            access points.

            When using a declarative network specification you cannot persist any
            settings via wpa_gui or wpa_cli.
          '';
        };

        group = mkOption {
          type = types.str;
          default = "wheel";
          example = "network";
          description = "Members of this group can control wpa_supplicant.";
        };
      };

      dbusControlled = mkOption {
        type = types.bool;
        default = lib.length cfg.interfaces < 2;
        defaultText = literalExpression "length config.services.wpa_supplicant.interfaces < 2";
        description = ''
          Whether to enable the DBus control interface.
          This is only needed when using NetworkManager or connman.
        '';
      };

      extraConfig = mkOption {
        type = types.str;
        default = "";
        example = ''
          p2p_disabled=1
        '';
        description = ''
          Extra lines appended to the configuration file.
          See
          {manpage}`wpa_supplicant.conf(5)`
          for available options.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    assertions =
      flip mapAttrsToList cfg.networks (
        name: cfg: {
          assertion =
            with cfg;
            count (x: x != null) [
              psk
              pskRaw
              auth
            ] <= 1;
          message = ''options networking.wireless."${name}".{psk,pskRaw,auth} are mutually exclusive'';
        }
      ) ++ [
    {
      assertion = cfg.userControlled.enable || (cfg.networks != { });
      message = ''
        Wireless networks must be defined or
        wpa_supplicant must be user controllable.
      '';
    }
    {
      assertion = builtins.elem config.boot.serviceManager [ "synit" ];
      message = "wpa_supplicant service not defined for the ${config.boot.serviceManager} service-manager";
    }];

    # hardware.wirelessRegulatoryDatabase = true;

    environment.systemPackages = [ pkgs.wpa_supplicant ];

    # If no interfaces are explicitly configured
    # then start an instance of wpa_supplicant for
    # each device asserted at runtime.
    #
    synit.plan.config.wpa_suplicant = lib.mkIf (cfg.interfaces == []) [ ''
      $machine ? <wlan ?iface> [
        let ?name = join "-" [ "wpa_supplicant" $iface ]
        let ?ifaceArg = join "" [ "-i" $iface ]
        $config += <depends-on <milestone network> <service-state <daemon $name> ready>>
        $config += <daemon $name {
          argv: [ ${[
            "${pkgs.wpa_supplicant}/bin/wpa_supplicant"
            "-D${cfg.driver}"
            ] ++ (
              if cfg.allowAuxiliaryImperativeNetworks then
                [ "-c/etc/wpa_supplicant.conf" "-I${configFile}" ]
              else
                [ "-c${configFile}" ]
            ) |> map builtins.toJSON |> toString} $ifaceArg ]
        }>
      ]
    '' ];

    # If interfaces are explicitly configured then instantiate
    # a singe instance of wpa_supplicant over all of them.
    #
    synit.daemons.wpa_supplicant = lib.mkIf (cfg.interfaces != []) {
      argv = [
        "${pkgs.wpa_supplicant}/bin/wpa_supplicant"
        "-D${cfg.driver}"
      ] ++ (
        if cfg.allowAuxiliaryImperativeNetworks then
          [ "-c/etc/wpa_supplicant.conf" "-I${configFile}" ]
        else
          [ "-c${configFile}" ]
      ) ++ map (i: "-I${i}") cfg.interfaces;
      provides = [ [ "milestone" "network" ] ];
    };
  };

}
