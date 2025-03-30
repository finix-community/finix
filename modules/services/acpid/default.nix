{ config, pkgs, lib, ... }:
let
  cfg = config.services.acpid;

  handlerOpts = {
    options = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };

      event = lib.mkOption {
        type = lib.types.str;
        example = lib.literalExpression ''"button/power.*" "button/lid.*" "ac_adapter.*" "button/mute.*" "button/volumedown.*" "cd/play.*" "cd/next.*"'';
        description = "Event type.";
      };

      action = lib.mkOption {
        type = lib.types.lines;
        description = "Shell commands to execute when the event is triggered.";
      };
    };
  };
in
{
  options.services.acpid = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    handlers = lib.mkOption {
      type = with lib.types; attrsOf (submodule handlerOpts);
      default = { };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc =
      let
        etcTree = lib.mapAttrs' (k: v: lib.nameValuePair "acpi/events/${k}" {
          text = ''
            event=${v.event}
            action=${pkgs.writeShellScriptBin "${k}.sh" v.action}/bin/${k}.sh '%e'
          '';
        }) (lib.filterAttrs (_: v: v.enable) config.services.acpid.handlers);
      in
        lib.mkMerge [ etcTree ];

    finit.services.acpid = {
      description = "acpi daemon";
      conditions = [ "service/syslogd/ready" ];
      command = "${pkgs.acpid}/bin/acpid --foreground --netlink";
      log = true;

      # TODO: add "if" to finit.services
      extraConfig = "if:<!int/container>";
    };
  };
}
