{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.dbus;

  homeDir = "/run/dbus";

  configDir = pkgs.makeDBusConf.override {
    suidHelper = "${config.security.wrapperDir}/dbus-daemon-launch-helper";
    serviceDirectories = cfg.packages;
  };

  inherit (lib) mkOption mkIf types;
in
{
  options.services.dbus = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable [dbus](${pkgs.dbus.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.dbus;
      defaultText = lib.literalExpression "pkgs.dbus";
      apply =
        package:
        if cfg.debug then
          package.overrideAttrs (o: {
            configureFlags = o.configureFlags ++ [ "--enable-verbose-mode" ];
          })
        else
          package;
      description = ''
        The package to use for `dbus`.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.
      '';
    };

    packages = mkOption {
      type = types.listOf types.path;
      default = [ ];
      description = ''
        Packages whose D-Bus configuration files should be included in
        the configuration of the D-Bus system-wide or session-wide
        message bus.  Specifically, files in the following directories
        will be included into their respective DBus configuration paths:
        {file}`«pkg»/etc/dbus-1/system.d`
        {file}`«pkg»/share/dbus-1/system.d`
        {file}`«pkg»/share/dbus-1/system-services`
        {file}`«pkg»/etc/dbus-1/session.d`
        {file}`«pkg»/share/dbus-1/session.d`
        {file}`«pkg»/share/dbus-1/services`
      '';
    };
  };

  config = mkIf cfg.enable {
    environment.etc."dbus-1".source = configDir;

    environment.pathsToLink = [
      "/etc/dbus-1"
      "/share/dbus-1"
    ];

    users.users = {
      messagebus = {
        # uid = config.ids.uids.messagebus;
        description = "D-Bus system message bus daemon user";
        home = homeDir;
        # homeMode = "0755";
        group = "messagebus";
      };
    };

    finit.tmpfiles.rules = [
      "d /run/dbus 0755 messagebus messagebus"
      "d /run/lock/subsys 0755 messagebus messagebus"
      "d /var/lib/dbus 0755 messagebus messagebus"
      "d /tmp/dbus 0755 messagebus messagebus"
    ];

    # users.groups.messagebus.gid = config.ids.gids.messagebus;
    users.groups = {
      messagebus = { };
    };

    # Install dbus for dbus tools even when using dbus-broker
    environment.systemPackages = [
      cfg.package
    ];

    services.dbus.packages = [
      cfg.package
      config.environment.path
    ];

    security.wrappers.dbus-daemon-launch-helper = {
      source = "${cfg.package}/libexec/dbus-daemon-launch-helper";
      owner = "root";
      group = "messagebus";
      setuid = true;
      setgid = false;
      permissions = "u+rx,g+rx,o-rx";
    };

    finit.services.dbus = {
      description = "d-bus message bus daemon";
      runlevels = "S123456789";
      conditions = "service/syslogd/ready";
      command = "${cfg.package}/bin/dbus-daemon --nofork --system --syslog-only";
      notify = "systemd";
      cgroup.name = "system";

      pre = pkgs.writeShellScript "dbus-pre.sh" "${cfg.package}/bin/dbus-uuidgen --ensure";
      environment = {
        DBUS_VERBOSE = lib.mkIf cfg.debug 1;
      };
    };

    # TODO: add finit.services.reloadTriggers option
    environment.etc."finit.d/dbus.conf".text = lib.mkAfter ''

      # reload trigger
      # ${config.environment.etc."dbus-1".source}
    '';
  };
}
