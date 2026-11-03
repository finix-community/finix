{
  config,
  pkgs,
  lib,
  ...
}:
let
  moduleSettingsType =
    with lib.types;
    attrsOf (
      nullOr (oneOf [
        bool
        str
        int
        pathInStore
      ])
    );

  moduleSettingsDescription = ''
    Boolean values render just the key if true, and nothing if false.
    Null values are ignored.
    All other values are rendered as key-value pairs.
  '';

  ruleNameOption = lib.mkOption {
    type = lib.types.str;
    description = ''
      Name of this rule.
    '';
    readOnly = true;
  };

  ruleEnableOption = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether this rule is added to the PAM service config file.
    '';
  };

  ruleOrderOption = lib.mkOption {
    type = lib.types.int;
    description = ''
      Order of this rule in the service file. Rules are arranged in ascending order of this value.

      ::: {.warning}
      The `order` values for the built-in rules are subject to change. If you assign a constant value to this option, a system update could silently reorder your rule. You could be locked out of your system, or your system could be left wide open. When using this option, set it to a relative offset from another rule's `order` value:

      ```nix
      {
        security.pam.services.login.rules.auth.foo.order =
          config.security.pam.services.login.rules.auth.unix.order + 10;
      }
      ```
      :::
    '';
  };

  ruleControlOption = lib.mkOption {
    type = lib.types.str;
    description = ''
      Indicates the behavior of the PAM-API should the module fail to succeed in its authentication task. See `control` in {manpage}`pam.conf(5)` for details.
    '';
  };

  ruleModulePathOption = lib.mkOption {
    type = lib.types.str;
    description = ''
      Either the full filename of the PAM to be used by the application (it begins with a '/'), or a relative pathname from the default module location. See `module-path` in {manpage}`pam.conf(5)` for details.
    '';
  };

  ruleArgsOption = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    description = ''
      Tokens that can be used to modify the specific behavior of the given PAM. Such arguments will be documented for each individual module. See `module-arguments` in {manpage}`pam.conf(5)` for details.

      Escaping rules for spaces and square brackets are automatically applied.

      {option}`settings` are automatically added as {option}`args`. It's recommended to use the {option}`settings` option whenever possible so that arguments can be overridden.
    '';
  };

  ruleSettingsOption = lib.mkOption {
    type = moduleSettingsType;
    default = { };
    description = ''
      Settings to add as `module-arguments`.

      ${moduleSettingsDescription}
    '';
  };

  settingsToArgs =
    settings:
    lib.concatLists (
      lib.flip lib.mapAttrsToList settings (
        name: value:
        if lib.isBool value then
          lib.optional value name
        else
          lib.optional (value != null) "${name}=${toString value}"
      )
    );

  escapeArg =
    arg: if lib.hasInfix " " arg then "[${lib.replaceStrings [ "]" ] [ "\\]" ] arg}]" else arg;

  formatRule =
    type: rule:
    lib.concatStringsSep " " (
      [
        type
        rule.control
        rule.modulePath
      ]
      ++ map escapeArg rule.args
    );

  ruleModule =
    { name, config, ... }:
    {
      options = {
        name = ruleNameOption;
        enable = ruleEnableOption;
        order = ruleOrderOption;
        control = ruleControlOption;
        modulePath = ruleModulePathOption;
        args = ruleArgsOption;
        settings = ruleSettingsOption;
      };
      config = {
        inherit name;
        args = settingsToArgs config.settings;
      };
    };

  rulesType = lib.types.attrsOf (lib.types.submodule ruleModule);

  mkRulesTypeOption =
    type:
    lib.mkOption {
      # These options are experimental and subject to breaking changes without notice.
      description = ''
        PAM `${type}` rules for this service.

        Attribute keys are the name of each rule.
      '';
      type = rulesType;
    };

  ruleTypes = [
    "account"
    "auth"
    "password"
    "session"
  ];

  # Enabled rules of a single type, sorted by `order` with ties broken by name.
  orderRules =
    rules:
    lib.sort (a: b: if a.order == b.order then a.name < b.name else a.order < b.order) (
      lib.filter (rule: rule.enable) (lib.attrValues rules)
    );

  pamOpts =
    { name, config, ... }:
    {
      options = {
        enable = lib.mkEnableOption "this PAM service" // {
          default = true;
          example = false;
        };

        name = lib.mkOption {
          type = lib.types.str;
          default = name;
          description = "Name of the PAM service.";
        };

        rules = lib.mkOption {
          description = ''
            PAM rules for this service.

            ::: {.warning}
            This option and its suboptions are experimental and subject to breaking changes without notice.
            :::
          '';
          type = lib.types.submodule {
            options = lib.genAttrs ruleTypes mkRulesTypeOption;
          };
        };

        orderedRules = lib.mkOption {
          type = lib.types.attrsOf (lib.types.listOf lib.types.raw);
          readOnly = true;
          description = ''
            The enabled {option}`rules` of this service for each rule type, sorted by `order` with ties broken by name.

            Use this to inspect the final order of the rules:

            ```
            nix-repl> map (r: "''${r.name} ''${toString r.order}") config.security.pam.services.login.orderedRules.auth
            ```
          '';
        };

        text = lib.mkOption {
          type = lib.types.lines;
        };
      };

      config = {
        orderedRules = lib.genAttrs ruleTypes (type: orderRules config.rules.${type});

        text = lib.mkDefault (
          lib.concatMapStrings (
            type: lib.concatMapStrings (rule: formatRule type rule + "\n") config.orderedRules.${type}
          ) ruleTypes
        );
      };
    };

  cfg = config.security.pam;
in
{
  options.security.pam = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.pam;
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    services = lib.mkOption {
      type = with lib.types; attrsOf (submodule pamOpts);
      default = { };
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options =
            let
              optionType =
                with lib.types;
                let
                  atom = oneOf [
                    int
                    str
                    path
                  ];
                in
                nullOr (coercedTo atom lib.singleton (listOf atom));
            in
            {
              default = lib.mkOption {
                type = optionType;
                default = null;
                apply =
                  let
                    toStr = v: if lib.isPath v then "${v}" else toString v;
                  in
                  v: if v == null then null else lib.concatMapStringsSep ":" toStr v;
                description = ''
                  The `DEFAULT` environment variables to be set, unset or modified by {manpage}`pam_env(8)`. See
                  {manpage}`pam_env.conf(5)` for additional details.
                '';
              };

              override = lib.mkOption {
                type = optionType;
                default = null;
                apply =
                  let
                    toStr = v: if lib.isPath v then "${v}" else toString v;
                  in
                  v: if v == null then null else lib.concatMapStringsSep ":" toStr v;
                description = ''
                  The environment variables to be set, unset or modified by {manpage}`pam_env(8)`. See
                  {manpage}`pam_env.conf(5)` for additional details.
                '';
              };
            };
        }
      );
      default = { };
      description = "Set of rules for {manpage}`pam_env(8)`.";
    };
  };

  config = {
    finit.tmpfiles.rules = [
      "d /var/lib/lastlog 0755 - - -"
    ];

    environment.etc =
      let
        etcTree = lib.mapAttrs' (
          k: v:
          lib.nameValuePair "pam.d/${k}" {
            inherit (v) text;
          }
        ) (lib.filterAttrs (_: v: v.enable) config.security.pam.services);

        debug = lib.mkIf config.security.pam.debug {
          "pam_debug".text = "";
        };

        pam_env."security/pam_env.conf".text =
          let
            toField = key: val: lib.optionalString (val != null) " ${key}=${val}";
          in
          lib.concatMapAttrsStringSep "\n" (
            var: { default, override }: "${var}${toField "DEFAULT" default}${toField "OVERRIDE" override}"
          ) cfg.environment;
      in
      lib.mkMerge [
        debug
        pam_env
        etcTree
      ];

    security.pam.environment = lib.mapAttrs (_: default: { inherit default; }) {
      NIX_REMOTE = "daemon";
      NIX_XDG_DESKTOP_PORTAL_DIR = "/run/current-system/sw/share/xdg-desktop-portal/portals";
      PATH = [
        "/etc/profiles/per-user/@{PAM_USER}/bin"
        "/run/current-system/sw/bin"
      ];
      XCURSOR_PATH = [
        "/run/current-system/sw/share/icons"
        "/run/current-system/sw/share/pixmaps"
      ];
      XDG_CONFIG_DIRS = [
        "/etc/xdg"
        "/run/current-system/sw/etc/xdg"
      ];
      XDG_DATA_DIRS = [
        "/run/current-system/sw/share"
        "/etc/profiles/per-user/@{PAM_USER}/share"
      ];
    };

    security.pam.services.other = {
      text = ''
        auth     required pam_warn.so
        auth     required pam_deny.so
        account  required pam_warn.so
        account  required pam_deny.so
        password required pam_warn.so
        password required pam_deny.so
        session  required pam_warn.so
        session  required pam_deny.so
      '';
    };

    security.wrappers = {
      unix_chkpwd = {
        setuid = true;
        owner = "root";
        group = "root";
        source = "${cfg.package}/bin/unix_chkpwd";
      };
    };
  };
}
