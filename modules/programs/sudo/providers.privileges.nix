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
          # sudo treats a bare command as "any arguments", "" means "no arguments"
          args = if rule.args == [ ] then ''""'' else toString rule.args;
        in
        ''
          ${lib.concatMapStringsSep "\n" (
            user: "${user} ALL = (${runAs}) ${opts} ${rule.command} ${args}"
          ) rule.users}
          ${lib.concatMapStringsSep "\n" (
            group: "%${group} ALL = (${runAs}) ${opts} ${rule.command} ${args}"
          ) rule.groups}
        ''
      ) config.providers.privileges.rules;
    };
  };
}
