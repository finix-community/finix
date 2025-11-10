{ config, lib, ... }:
{
  options.providers.privileges = {
    backend = lib.mkOption {
      type = lib.types.enum [ "sudo" ];
    };
  };

  config = lib.mkIf (config.providers.privileges.backend == "sudo") {
    providers.privileges.supportedFeatures = {
      # TODO:
    };

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
