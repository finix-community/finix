{ config, lib, ... }:
let
  providerWarning =
    rule:
    if
      (
        (lib.attrsets.filterAttrs (
          n: v: !(lib.elem n config.providers.privileges.supportedFeatures || v == null)
        ) rule) != { }
      )
    then
      "configuration has unsupported features for chosen privileges backend, ${config.providers.privileges.backend}. Attributes not on this list will be ignored:\n"
      + (lib.concatStringsSep "\n" config.providers.privileges.supportedFeatures)
    else
      "";
in
{
  options.providers.privileges = {
    backend = lib.mkOption {
      type = lib.types.enum [ "doas" ];
    };
  };

  config = lib.mkIf (config.providers.privileges.backend == "doas") {
    providers.privileges.supportedFeatures = [
      "command"
      "args"
      "users"
      "groups"
      "requirePassword"
      "persist"
      "keepEnv"
      "keepEnvVars"
      "runAs"
    ];

    warnings = [
      "Vitrial still hasn't added all the rules they need to for privileges"
    ]
    ++ (lib.map providerWarning config.providers.privileges.rules);

    providers.privileges.command = "/run/wrappers/bin/doas";

    environment.etc."doas.conf" = {
      text = lib.concatMapStringsSep "\n" (
        rule:
        let
          runAs = lib.optionalString (rule.runAs != "*") "as ${rule.runAs}";
          opts =
            lib.optionalString (!rule.requirePassword) "nopass "
            + lib.optionalString (rule.persist && rule.requirePassword) "persist "
            + (if rule.keepEnv then "keepenv" else "setenv { SSH_AUTH_SOCK TERMINFO TERMINFO_DIRS }");
          command = lib.optionalString (rule.command != "*") " cmd ${rule.command} ${toString rule.args}";
        in
        ''
          ${lib.concatMapStringsSep "\n" (user: "permit ${opts} ${user} ${runAs}${command}") rule.users}
          ${lib.concatMapStringsSep "\n" (group: "permit ${opts} :${group} ${runAs}${command}") rule.groups}
        ''
      ) config.providers.privileges.rules;
    };
  };
}
