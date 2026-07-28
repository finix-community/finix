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
      null;

  checkPersist =
    rule:
    if (rule.persist != null) then
      "sudo does not support per option persistence. please use 'programs.sudo.persistTimer = <time>'"
    else
      null;
in
{
  options.providers.privileges = {
    backend = lib.mkOption {
      type = lib.types.enum [ "sudo" ];
    };
  };

  config = lib.mkIf (config.providers.privileges.backend == "sudo") {
    providers.privileges.supportedFeatures = [
      "command"
      "args"
      "users"
      "groups"
      "requirePassword"
      "persist"
      "runAs"
    ];

    warnings = [
      "Vitrial still hasn't added all the rules they need to for privileges"
    ]
    + lib.map checkPersist config.providers.priviliges.rules
    + lib.map providerWarning config.providers.privileges.rules;

    providers.privileges.command = "/run/wrappers/bin/sudo";

    environment.etc.sudoers = {
      text = lib.concatMapStringsSep "\n" (
        rule:
        let
          runAs = if rule.runAs == "*" then "ALL" else rule.runAs;
          opts = lib.optionalString (!rule.requirePassword) "NOPASSWD:";
        in
        ''
          ${lib.concatMapStringsSep "\n" (
            user: "${user} ALL = (${runAs}) ${opts} ${rule.command} ${toString rule.args}"
          ) rule.users}
          ${lib.concatMapStringsSep "\n" (
            group: "%${group} ALL = (${runAs}) ${opts} ${rule.command} ${toString rule.args}"
          ) rule.groups}
        ''
      ) config.providers.privileges.rules;
    };
  };
}
