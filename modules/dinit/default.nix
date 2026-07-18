{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.dinit;

  format = pkgs.formats.keyValue { };

  envFormat = pkgs.formats.keyValue {
    mkKeyValue = k: v: "${k}=${toString v}";
  };
in
{
  options.dinit = {
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.dinit;
      defaultText = lib.literalExpression "pkgs.dinit";
      description = ''
        The dinit package to use.
      '';
    };

    user.services = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { config, name, ... }: {
            imports = [ ./common-options.nix ];

            config.env-file = lib.mkIf (config.environment != { }) (
              envFormat.generate "${name}.env" config.environment
            );
          }
        )
      );
      default = { };
      description = ''
        An attribute set of `dinit` user level services.

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html) for additional details.
      '';
    };

    services = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule (
          { config, name, ... }: {
            imports = [
              ./common-options.nix
              ./system-options.nix
            ];

            config.env-file = lib.mkIf (config.environment != { }) (
              envFormat.generate "${name}.env" config.environment
            );
          }
        )
      );
      default = { };
      description = ''
        An attribute set of `dinit` system level services.

        See [upstream documentation](https://davmac.org/projects/dinit/man-pages-html/dinit-service.5.html) for additional details.
      '';
    };
  };

  config = {
    environment.systemPackages = lib.mkIf (cfg.services != { } || cfg.user.services != { }) [
      cfg.package
    ];

    environment.etc =
      let
        settingsFormat = import ./format.nix { inherit pkgs lib; };
        extraAttrs = [
          "enable"
          "environment"
          "path"
          "boot"
        ];


        userTree = lib.mapAttrs' (name: service: {
          name = "dinit.d/user/${name}";
          value.source = settingsFormat.generate name (builtins.removeAttrs service extraAttrs);
        }) (lib.filterAttrs (_: service: service.enable) cfg.user.services);

        systemTree = lib.mapAttrs' (name: service: {
          name = "dinit.d/${name}";
          value.source = settingsFormat.generate name (builtins.removeAttrs service extraAttrs);
        }) (lib.filterAttrs (_: service: service.enable) cfg.services);
      in
      userTree // systemTree // {
        "dinit.d/boot".source = settingsFormat.generate "boot" {
          type = "internal";
          "depends-on.d" = "boot.d";
        };
        "dinit.d/boot.d/.keep".text = "";
      };

    system.activation.scripts.dinitBootD = {
      deps = [ "etc" ];
      text = ''
        boot_d="/etc/dinit.d/boot.d"
        find "$boot_d" -maxdepth 1 -type l -exec rm -f {} +
      '' + lib.concatMapStrings (
        name: "ln -sf ../${name} $boot_d/${name}\n"
      ) (lib.attrNames (lib.filterAttrs (_: s: s.boot) cfg.services));
    };
    dinit.services.mount-fstab = {
      type = "scripted";
      command = "${pkgs.util-linux}/bin/mount -a";
      boot = true;
    };
    system.activation.scripts.dinit-reload = {
      deps = [ "etc" "dinitBootD" ];
      text = let
        enabledNames = lib.attrNames (lib.filterAttrs (_: s: s.enable) cfg.services);
        enabledList = lib.concatStringsSep " " (map (n: "\"${n}\"") enabledNames);
        enabledAssoc = lib.concatMapStringsSep " " (n: "[\"${n}\"]=1") enabledNames;
        dinitctl = "${cfg.package}/bin/dinitctl";
      in ''
        # TODO: newly-enabled services are only reloaded below, never started; removed services
        # are stopped but not unloaded, so stale definitions linger until reboot.
        # Reload definitions for services in the new config
        for svc in ${enabledList}; do
          ${dinitctl} reload "$svc" 2>&1 | logger -t finix-dinit || true
        done

        # Stop services that were enabled in the previous generation but are no longer enabled.
        # Never touch "boot": stopping it drops its explicit activation, which releases
        # every dependency in boot.d and takes down the whole service tree.
        oldServiceDir="/run/current-system/etc/dinit.d"
        if [ -d "$oldServiceDir" ]; then
          declare -A enabled_services=( ${enabledAssoc} )
          for f in "$oldServiceDir"/*; do
            [ -e "$f" ] || continue
            name="$(basename "$f")"
            [ "$name" = "boot" ] && continue
            [ "$name" = "boot.d" ] && continue
            if [ -z "''${enabled_services[$name]-}" ]; then
              ${dinitctl} stop --no-wait "$name" 2>&1 | logger -t finix-dinit || true
            fi
          done
        fi
      '';
    };
  };
}
