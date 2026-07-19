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

  dinitManifest = pkgs.writeText "dinit-manifest.json" (builtins.toJSON (
    lib.attrNames (lib.filterAttrs (_: s: s.enable) cfg.services)
  ));

  dinitSwitchScript = pkgs.writeText "dinit-switch.py" ''
import json, subprocess, sys, os, argparse

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--dinitctl", required=True)
    parser.add_argument("--manifest", required=True)
    args = parser.parse_args()

    with open(args.manifest) as f:
        desired = set(json.load(f))

    result = subprocess.run(
        [args.dinitctl, "list"], capture_output=True, text=True
    )
    if result.returncode != 0:
        sys.exit(0)

    current = set()
    for line in result.stdout.splitlines():
        if not line.startswith("["):
            continue
        rest = line.split("]", 1)
        if len(rest) == 2:
            name = rest[1].strip().split(None, 1)[0]
            if name not in ("boot", "default"):
                current.add(name)

    for svc in sorted(current - desired):
        print(f"dinit-switch: removing '{svc}'")
        subprocess.run([args.dinitctl, "rm-dep", "need", "boot", svc],
                     capture_output=True)
        subprocess.run([args.dinitctl, "rm-dep", "waits-for", "default", svc],
                     capture_output=True)
        r = subprocess.run([args.dinitctl, "stop", svc],
                         capture_output=True, text=True)
        if r.returncode != 0:
            print(f"dinit-switch: stop '{svc}' failed: {r.stderr.strip()}", file=sys.stderr)
            continue
        r = subprocess.run([args.dinitctl, "unload", svc],
                         capture_output=True, text=True)
        if r.returncode != 0:
            print(f"dinit-switch: unload '{svc}' failed: {r.stderr.strip()}", file=sys.stderr)
            continue
        for d in ("boot.d", "default.d"):
            p = f"/etc/dinit.d/{d}/{svc}"
            if os.path.exists(p):
                os.unlink(p)

    for svc in sorted(current & desired):
        r = subprocess.run([args.dinitctl, "reload", svc],
                         capture_output=True, text=True)
        if r.returncode != 0:
            print(f"dinit-switch: reload '{svc}' failed: {r.stderr.strip()}", file=sys.stderr)

if __name__ == "__main__":
    main()
  '';
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
          "default"
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
      userTree // systemTree // 
      {
        "dinit.d/boot".source = settingsFormat.generate "boot" {
          type = "internal";
          "depends-on.d" = "boot.d";
          "waits-for" = [ "default" ];
        };
        "dinit.d/boot.d/.keep".text = "";
      } 
      // 
      {
        "dinit.d/default".source = settingsFormat.generate "default" {
          type = "internal";
          "waits-for.d" = "default.d";
        };
        "dinit.d/default.d/.keep".text = "";
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
    system.activation.scripts.dinitDefaultD = {
      deps = [ "etc" ];
      text = ''
        default_d="/etc/dinit.d/default.d"
        find "$default_d" -maxdepth 1 -type l -exec rm -f {} +
      '' + lib.concatMapStrings (
        name: "ln -sf ../${name} $default_d/${name}\n"
      ) (lib.attrNames (lib.filterAttrs (_: s: s.default) cfg.services));
    };

    dinit.services.mount-fstab = {
      type = "scripted";
      command = "${pkgs.util-linux}/bin/mount -a";
      boot = true;
    };
    system.activation.scripts.dinit-switch = {
      deps = [ "etc" "dinitBootD" "dinitDefaultD" ];
      text = ''
        ${pkgs.python3}/bin/python3 ${dinitSwitchScript} \
          --dinitctl ${cfg.package}/bin/dinitctl \
          --manifest ${dinitManifest}
      '';
    };
  };
}
