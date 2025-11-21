{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.boot.bootspec;

  schemas = {
    v1 = rec {
      filename = "boot.json";
      json = pkgs.writeText filename (
        builtins.toJSON
          # Merge extensions first to not let them shadow NixOS bootspec data.
          (
            cfg.extensions
            // {
              "org.nixos.bootspec.v1" = {
                system = config.boot.kernelPackages.stdenv.hostPlatform.system;
                kernel = "${config.boot.kernelPackages.kernel}/bzImage";
                kernelParams = config.boot.kernelParams;
                # label = "${config.system.nixos.distroName} ${config.system.nixos.codeName} ${config.system.nixos.label} (Linux ${config.boot.kernelPackages.kernel.modDirVersion})";
                label = "finix (Linux ${config.boot.kernelPackages.kernel.modDirVersion})";
              }
              // lib.optionalAttrs config.boot.initrd.enable {
                initrd = "${config.boot.initrd.package}/initrd";
              };
            }
          )
      );

      generator =
        let
          # NOTE: Be careful to not introduce excess newlines at the end of the
          # injectors, as that may affect the pipes and redirects.

          # Inject toplevel and init into the bootspec.
          # This can only be done here because we *cannot* depend on $out
          # referring to the toplevel, except by living in the toplevel itself.
          toplevelInjector =
            lib.escapeShellArgs [
              "${pkgs.buildPackages.jq}/bin/jq"
              ''
                ."org.nixos.bootspec.v1".toplevel = $toplevel |
                ."org.nixos.bootspec.v1".init = $init
              ''
              "--sort-keys"
              "--arg"
              "toplevel"
              "${placeholder "out"}"
              "--arg"
              "init"
              "${placeholder "out"}/init"
            ]
            + " < ${json}";

          # We slurp all specialisations and inject them as values, such that
          # `.specialisations.${name}` embeds the specialisation's bootspec
          # document.
          specialisationInjector =
            let
              specialisationLoader = (
                lib.mapAttrsToList (
                  childName: childToplevel:
                  lib.escapeShellArgs [
                    "--slurpfile"
                    childName
                    "${childToplevel}/${filename}"
                  ]
                ) (lib.mapAttrs (k: v: v.system.topLevel) config.specialisation)
              );
            in
            lib.escapeShellArgs [
              "${pkgs.buildPackages.jq}/bin/jq"
              "--sort-keys"
              ''."org.nixos.specialisation.v1" = ($ARGS.named | map_values(. | first))''
            ]
            + " ${lib.concatStringsSep " " specialisationLoader}";
        in
        "${toplevelInjector} | ${specialisationInjector} > $out/${filename}";

      validator = pkgs.writeCueValidator ./bootspec.cue {
        document = "Document"; # Universal validator for any version as long the schema is correctly set.
      };
    };
  };
in
{
  options.boot.bootspec = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      internal = true;
      description = ''
        Whether to enable the generation of [RFC-0125](https://github.com/NixOS/rfcs/blob/master/rfcs/0125-bootspec.md)
        bootspec in `$system/boot.json`, e.g. `/run/current-system/boot.json`.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.bootspec;
      defaultText = lib.literalExpression "pkgs.bootspec";
      description = ''
        The package to use for `bootspec`.
      '';
    };

    enableValidation = lib.mkEnableOption ''
      the validation of bootspec documents for each build.
            This will introduce Go in the build-time closure as we are relying on [Cuelang](https://cuelang.org/) for schema validation.
            Enable this option if you want to ascertain that your documents are correct
    '';

    extensions = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = ''
        User-defined data that extends the bootspec document.

        To reduce incompatibility and prevent names from clashing
        between applications, it is **highly recommended** to use a
        unique namespace for your extensions.
      '';
    };

    # This will be run as a part of the `systemBuilder` in ./top-level.nix. This
    # means `$out` points to the output of `config.system.build.toplevel` and can
    # be used for a variety of things (though, for now, it's only used to report
    # the path of the `toplevel` itself and the `init` executable).
    writer = lib.mkOption {
      internal = true;
      default = schemas.v1.generator;
    };

    validator = lib.mkOption {
      internal = true;
      default = schemas.v1.validator;
    };

    filename = lib.mkOption {
      internal = true;
      default = schemas.v1.filename;
    };
  };
}
