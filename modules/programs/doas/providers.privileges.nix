{ config, lib, ... }:
let
	optionalStringElse = cond: string: elseString: if cond then string else elseString;
in
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
						+ lib.optionalString (rule.persist && rule.requirePassword) "persist "
						+ optionalStringElse (rule.keepEnv) "keepenv" "setenv { SSH_AUTH_SOCK TERMINFO TERMINFO_DIRS }";
					command = lib.optionalString (rule.command != "*") " cmd ${rule.command} ${toString rule.args}";
        in
        ''
          ${lib.concatMapStringsSep "\n" (
            user: "permit ${opts} ${user} ${runAs}${command}"
          ) rule.users}
          ${lib.concatMapStringsSep "\n" (
            group: "permit ${opts} :${group} ${runAs}${command}"
          ) rule.groups}
        ''
      ) config.providers.privileges.rules;
    };
  };
}
