{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.tlp;
  tlpExe = lib.getExe cfg.package;

  format = pkgs.formats.keyValue {
    mkKeyValue = lib.generators.mkKeyValueDefault { } "=";
    listToValue = l: "\"${toString l}\"";
  };
in
{
  options.services.tlp = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [tlp](${pkgs.tlp.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.tlp;
      defaultText = lib.literalExpression "pkgs.tlp";
      description = ''
        The package to use for `tlp`.
      '';
    };

    settings = lib.mkOption {
      type = format.type;
      default = { };
      description = ''
        `tlp` configuration. See [upstream documentation](https://linrunner.de/tlp/settings)
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc."tlp.conf".source = format.generate "tlp.conf" cfg.settings;

    environment.systemPackages = [
      cfg.package
    ];

    services.tmpfiles.tlp.rules = [
      "d /var/lib/tlp"
    ];

    providers.resumeAndSuspend.hooks = {
      "tlp@suspend" = {
        event = "suspend";
        action = "${tlpExe} suspend";
      };

      "tlp@resume" = {
        event = "resume";
        action = "${tlpExe} resume";
      };
    };

    services.udev.packages = [ cfg.package ];

    # TODO: revisit rules... compare with udev
    services.mdevd.hotplugRules = ''
      # handle change of power source ac/bat
      -SUBSYSTEM=power_supply;.* root:root 0600 &${tlpExe} auto

      # handle added usb devices
      # -SUBSYSTEM=usb;DEVTYPE=usb_device;.* root:root 0600 +${cfg.package}/lib/udev/tlp-usb-udev usb /sys/$DEVPATH

      # handle added usb disk devices
      # -SUBSYSTEM=block;DEVTYPE=disk;.* root:root 0600 +${cfg.package}/lib/udev/tlp-usb-udev disk /sys/$DEVPATH
    '';

    finit.tasks = {
      "tlp@start" = {
        description = "tlp system startup";
        command = "${tlpExe} init start";
        conditions = "service/syslogd/ready";
        runlevels = "S";
      };

      "tlp@reload" = {
        description = "tlp system reload";
        command = "${tlpExe} start";
        conditions = "service/syslogd/ready";
      };

      "tlp@stop" = {
        description = "tlp system shutdown";
        command = "${tlpExe} init stop";
        conditions = "service/syslogd/ready";
        runlevels = "06";
      };
    };

    # TODO: add finit.services.restartTriggers option
    environment.etc."finit.d/tlp@reload.conf".text = lib.mkAfter ''

      # standard nixos trick to force a restart when something has changed
      # ${config.environment.etc."tlp.conf".source}
    '';

    synit.daemons = {
      tlp = {
        argv = [
          tlpExe
          "start"
        ];
        restart = "on-error";
      };
    };
  };
}
