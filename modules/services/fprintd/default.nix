{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.fprintd;
in
{
  options.services.fprintd = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [fprintd](${pkgs.fprintd.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.fprintd;
      defaultText = lib.literalExpression "pkgs.fprintd";
      description = ''
        The package to use for `fprintd`.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.
      '';
    };

    extraGroups = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      example = lib.literalExpression "[ config.services.seatd.group ]";
      description = ''
        A list of groups to _unconditionally_ grant access, via `polkit`, to this services offerings. Useful
        on systems without `(e)logind`. See [Using polkit with seatd](https://wiki.alpinelinux.org/wiki/Polkit#Using_polkit_with_seatd)
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.polkit.enable;
        message = "services.fprintd requires services.polkit.enable set to true";
      }
    ];

    environment.systemPackages = [ cfg.package ];

    services.dbus.packages = [ cfg.package ];
    services.polkit.extraConfig = lib.optionalString (cfg.extraGroups != [ ]) ''
      polkit.addRule(function(action, subject) {
        if (action.id.startsWith("net.reactivated.fprint.device.")) {
          var groups = ${builtins.toJSON cfg.extraGroups};

          if (groups.some(function(group) {
            return subject.isInGroup(group);
          })) {
            return polkit.Result.YES;
          }
        }

        return polkit.Result.NOT_HANDLED;
      });
    '';

    finit.services.fprintd = {
      description = "fingerprint authentication daemon";
      command = "${cfg.package}/libexec/fprintd --no-timeout";
      conditions = "service/polkit/ready";
      nohup = true;
      log = true;

      # TODO: now we're hijacking `env` and no one else can use it...
      environment = {
        G_MESSAGES_DEBUG = lib.mkIf cfg.debug "all";
      };
    };
  };
}
