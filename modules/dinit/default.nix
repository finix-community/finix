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
    mkKeyValue = k: v: "${k}=${v}";
  };
in
{
  options.dinit = {
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
      pkgs.dinit
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
      text = lib.concatMapStrings (
        name: "ln -sf ../${name} /etc/dinit.d/boot.d/${name}\n"
      ) (lib.attrNames (lib.filterAttrs (_: s: s.boot) cfg.services));
    };
    dinit.services.mount-fstab = {
      type = "scripted";
      command = "${pkgs.util-linux}/bin/mount -a";
      waits-for = [ "boot" ];
      boot = true;
    };
    system.activation.scripts.dinit-reload = {
          deps = [ "etc" "dinitBootD" ];
          text = let
            enabledNames = lib.attrNames (lib.filterAttrs (_: s: s.enable) cfg.services);
            enabledList = lib.concatStringsSep " " (map (n: "\"${n}\"") enabledNames);
            dinitctl = "${pkgs.dinit}/bin/dinitctl";
          in ''
            # Reload definitions for services in the new config
            for svc in ${enabledList}; do
              ${dinitctl} reload "$svc" 2>/dev/null || true
            done

            # Stop services no longer in the config
            enabled_set="${enabledList}"
            ${dinitctl} list 2>/dev/null | while IFS= read -r line; do
            if [[ "$line" =~ ^\[[[:space:]]*\{[+-]\}[[:space:]]*\][[:space:]]+([a-zA-Z0-9_-]+) ]]; then
                name="''${BASH_REMATCH[1]}"
                case " $enabled_set " in
                  *" ''${name} "*) ;;
                  *) ${dinitctl} stop --no-wait "$name" 2>/dev/null || true ;;
                esac
              fi
            done
          '';
        };
  };
}
