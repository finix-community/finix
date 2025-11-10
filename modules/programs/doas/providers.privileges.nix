{ config, lib, ... }:
{
  options.providers.privileges = {
    backend = lib.mkOption {
      type = lib.types.enum [ "doas" ];
    };
  };

  config = lib.mkIf (config.providers.privileges.backend == "doas") {
    providers.privileges.supportedFeatures = {
      # TODO:
    };

    providers.privileges.command = "/run/wrappers/bin/doas";

    environment.etc."doas.conf" = {
      text = lib.concatMapStringsSep "\n" (
        rule:
        let
          runAs = lib.optionalString (rule.runAs != "*") "as ${rule.runAs}";
          opts =
            lib.optionalString (!rule.requirePassword) "nopass "
            + "setenv { SSH_AUTH_SOCK TERMINFO TERMINFO_DIRS }";
        in
        ''
          ${lib.concatMapStringsSep "\n" (
            user: "permit ${opts} ${user} ${runAs} cmd ${rule.command} ${toString rule.args}"
          ) rule.users}
          ${lib.concatMapStringsSep "\n" (
            group: "permit ${opts} :${group} ${runAs} cmd ${rule.command} ${toString rule.args}"
          ) rule.groups}
        ''
      ) config.providers.privileges.rules;
    };
  };
}
