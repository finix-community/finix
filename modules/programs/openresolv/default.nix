{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.openresolv;

  listToValue = lib.concatMapStringsSep " " (lib.generators.mkValueStringDefault { });

  format = (pkgs.formats.keyValue { inherit listToValue; }) // {
    generate =
      name: value:
      let
        transformedValue = lib.mapAttrs (
          key: val:
          if lib.isList val then
            "'" + listToValue val + "'"
          else if lib.isBool val then
            lib.boolToString val
          else
            toString val
        ) value;
      in
      pkgs.writeText name (lib.generators.toKeyValue { } transformedValue);
  };
in
{
  options.programs.openresolv = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [openresolv](${pkgs.openresolv.meta.homepage}).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.openresolv.overrideAttrs (_: {
        # TODO: could potentially make 'RESTARTCMD' an overridable option for the package
        configurePhase = ''
          cat > config.mk <<EOF
          PREFIX=$out
          SYSCONFDIR=/etc
          SBINDIR=$out/sbin
          LIBEXECDIR=$out/libexec/resolvconf
          VARDIR=/run/resolvconf
          MANDIR=$out/share/man
          RESTARTCMD="initctl restart \\\\\$\$1"
          EOF
        '';
      });
      defaultText = lib.literalExpression "pkgs.openresolv";
      description = ''
        The package to use for `openresolv`.
      '';
    };

    settings = lib.mkOption {
      type = format.type;
      default = { };
      description = ''
        `openresolv` configuration. See {manpage}`resolvconf.conf(5)`
        for additional details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    programs.openresolv.settings = {
      interface_order = [
        "lo"
        "lo[0-9]"
      ];
      resolv_conf = "/etc/resolv.conf";
    };

    environment.etc."resolvconf.conf".source = format.generate "resolvconf.conf" cfg.settings;

    environment.systemPackages = [ cfg.package ];

    finit.tasks.openresolv = {
      command = "${lib.getExe cfg.package} -u";
    };

    environment.etc."finit.d/openresolv.conf".text = lib.mkAfter ''

      # force a restart on configuration change
      # ${config.environment.etc."resolvconf.conf".source}
    '';
  };
}
