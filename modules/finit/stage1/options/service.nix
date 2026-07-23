{ lib, config }:
{
  options = {
    notify = lib.mkOption {
      type = lib.types.enum [
        "none"
        "pid"
        "s6"
      ];
      default = config.finit.readiness;
      defaultText = lib.literalExpression "config.finit.readiness";
      description = ''
        See [upstream documentation](https://finit-project.github.io/config/service-sync/) for details.
      '';
    };

    restart = lib.mkOption {
      type = with lib.types; nullOr (ints.between (-1) 255);
      default = null;
      description = ''
        The number of times `finit` tries to restart a crashing service. When
        this limit is reached the service is marked crashed and must be restarted
        manually with `initctl restart NAME`. When `null`, finit's built-in
        default applies.
      '';
    };

    respawn = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable endless restarts without counting toward the retry limit. When set, the service
        will be restarted indefinitely regardless of the `restart` limit.
      '';
    };
  };
}
