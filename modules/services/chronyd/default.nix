{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.chrony;

  notifySupport = lib.versionAtLeast cfg.package.version "4.9";
in
{
  options.services.chrony = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [chrony](${pkgs.chrony.meta.homepage}) as a system service.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.chrony;
      defaultText = lib.literalExpression "pkgs.chrony";
      apply =
        package:
        if cfg.debug then
          package.overrideAttrs (o: {
            configureFlags = o.configureFlags ++ [ "--enable-debug" ];
          })
        else
          package;
      description = ''
        The package to use for `chrony`.
      '';
    };

    debug = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable debug logging.
      '';
    };

    extraArgs = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      description = ''
        Additional arguments to pass to `dropbear`. See {manpage}`chronyd(8)`
        for additional details.
      '';
    };

    configFile = lib.mkOption {
      type = lib.types.path;
      default = pkgs.writeText "chrony.conf" ''
        server 0.nixos.pool.ntp.org iburst
        server 1.nixos.pool.ntp.org iburst
        server 2.nixos.pool.ntp.org iburst
        server 3.nixos.pool.ntp.org iburst
        makestep 1.0 3
        rtcsync
        allow
        clientloglimit 100000000
        leapsectz right/UTC
        driftfile /var/lib/chrony/drift
        dumpdir /var/run/chrony
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.chrony.extraArgs = [
      "-n"
      "-u"
      "chrony"
      "-f"
      cfg.configFile
    ]
    ++ lib.optionals cfg.debug [
      "-L"
      "-1"
    ]
    ++ lib.optionals notifySupport [
      "-N"
      "%n"
    ];

    environment.systemPackages = [ cfg.package ];

    finit.services.chronyd = {
      description = "chrony ntp daemon";
      conditions = "service/syslogd/ready";
      command = "${cfg.package}/bin/chronyd " + lib.escapeShellArgs cfg.extraArgs;
      nohup = true;
      notify = lib.mkIf notifySupport "s6";

      # TODO: add "if" to finit.services
      extraConfig = "if:<!int/container>";
    };

    finit.tmpfiles.rules = [
      "d /var/lib/chrony 0750 chrony chrony - -"
      "f /var/lib/chrony/chrony.drift 0640 chrony chrony - -"
      "f /var/lib/chrony/chrony.keys 0640 chrony chrony - -"

      # "f /var/lib/chrony/chrony.rtc 0640 chrony chrony - -"
    ];

    users.users = {
      chrony = {
        uid = config.ids.uids.chrony;
        group = "chrony";
        description = "chrony daemon user";
        home = "/var/lib/chrony";
      };
    };

    users.groups = {
      chrony.gid = config.ids.gids.chrony;
    };
  };
}
