{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.programs.dconf;

  compileDconfDb =
    dir:
    pkgs.runCommandLocal "dconf-db"
      {
        nativeBuildInputs = [ (lib.getBin cfg.package) ];
      }
      ''
        dconf compile "$out" "${dir}"
      '';

  checkDconfKeyfiles =
    dir:
    pkgs.runCommandLocal "check-dconf-keyfiles"
      {
        nativeBuildInputs = [ (lib.getBin cfg.package) ];
      }
      ''
        if [[ -f ${dir} ]]; then
          echo "dconf keyfiles should be a directory but a file was provided: ${dir}"
          exit 1
        fi

        dconf compile db ${dir} || (
          echo "The dconf keyfiles are invalid: ${dir}"
          exit 1
        )
        cp -R ${dir} $out
      '';

  mkAllLocks =
    settings:
    lib.flatten (
      lib.mapAttrsToList (
        section: values: lib.mapAttrsToList (key: _: "/${section}/${key}") values
      ) settings
    );

  mkDconfDb =
    database:
    compileDconfDb (
      pkgs.symlinkJoin {
        name = "finix-generated-dconf-keyfiles";
        paths = [
          (pkgs.writeTextDir "finix-generated-dconf-keyfiles" (lib.generators.toDconfINI database.settings))
          (pkgs.writeTextDir "locks/finix-generated-dconf-locks" (
            lib.concatStringsSep "\n" (
              if database.lockAll then mkAllLocks database.settings else database.locks
            )
          ))
        ]
        ++ map checkDconfKeyfiles database.keyfiles;
      }
    );

  checkDconfDb =
    file:
    pkgs.runCommandLocal "check-dconf-db"
      {
        nativeBuildInputs = [ (lib.getBin cfg.package) ];
      }
      ''
        if [[ -d ${file} ]]; then
          echo "dconf DB should be a file but a directory was provided: ${file}"
          exit 1
        fi

        echo "file-db:${file}" > profile
        DCONF_PROFILE=$(pwd)/profile dconf dump / > output 2> error
        if [[ ! -s output ]] && [[ -s error ]]; then
          cat error
          echo "The dconf DB file is invalid: ${file}"
          exit 1
        fi

        cp ${file} $out
      '';

  mkDconfProfileFile =
    name: path:
    pkgs.runCommandLocal "dconf-profile" { } ''
      if [[ -d ${path} ]]; then
        echo "dconf profile should be a file but a directory was provided: ${path}"
        exit 1
      fi

      mkdir -p $out/etc/dconf/profile
      cp ${path} $out/etc/dconf/profile/${name}
    '';

  # a package providing /etc/dconf, as applications ship it
  mkDconfProfilePackage =
    name: package:
    pkgs.runCommandLocal "dconf-profile" { } ''
      if [[ ! -f ${package}/etc/dconf/profile/${name} ]]; then
        echo "${package} does not provide etc/dconf/profile/${name}"
        exit 1
      fi

      mkdir -p $out
      ln -s ${package}/etc $out/etc
    '';

  mkDconfProfile =
    name: value:
    if lib.isDerivation value then
      mkDconfProfilePackage name value
    else if lib.isPath value then
      mkDconfProfileFile name value
    else
      pkgs.writeTextDir "etc/dconf/profile/${name}" (
        lib.concatMapStrings (entry: "${entry}\n") (
          (lib.optional value.enableUserDb "user-db:user")
          ++ map (
            database:
            let
              db =
                if lib.isAttrs database && !lib.isDerivation database then
                  mkDconfDb database
                else
                  checkDconfDb database;
            in
            "file-db:${db}"
          ) value.databases
        )
      );

  dconfDatabase =
    with lib.types;
    submodule {
      options = {
        keyfiles = lib.mkOption {
          type = listOf (oneOf [
            path
            package
          ]);
          default = [ ];
          description = "Directories containing dconf keyfiles.";
        };

        settings = lib.mkOption {
          type = attrs;
          default = { };
          description = "Settings used to generate dconf keyfiles.";
          example = lib.literalExpression ''
            with lib.gvariant;
            {
              "org/finix/example" = {
                retries = mkUint32 3;
                enabled = true;
              };
            }
          '';
        };

        locks = lib.mkOption {
          type = listOf str;
          default = [ ];
          description = ''
            dconf keys to lock. This is ignored when {option}`lockAll` is enabled.
          '';
          example = lib.literalExpression ''
            [ "/org/finix/example/retries" ]
          '';
        };

        lockAll = lib.mkOption {
          type = bool;
          default = false;
          description = "Whether to lock all keys generated from {option}`settings`.";
        };
      };
    };

  dconfProfile =
    with lib.types;
    submodule {
      options = {
        enableUserDb = lib.mkOption {
          type = bool;
          default = true;
          description = "Whether to include the per-user dconf database in the profile.";
        };

        databases = lib.mkOption {
          type = listOf (oneOf [
            path
            package
            dconfDatabase
          ]);
          default = [ ];
          description = ''
            Databases used by this profile. Entries can be dconf database
            definitions, packages, or paths to already compiled database files.
          '';
        };
      };
    };
in
{
  options.programs.dconf = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [dconf](${pkgs.dconf.meta.homepage}).

        This only enables dconf integration; it does not select settings for a desktop environment.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.dconf;
      defaultText = lib.literalExpression "pkgs.dconf";
      description = ''
        The package to use for `dconf`.
      '';
    };

    profiles = lib.mkOption {
      type =
        with lib.types;
        attrsOf (oneOf [
          path
          package
          dconfProfile
        ]);
      default = { };
      description = ''
        dconf profiles. A profile named `user` is used by default by GLib.

        Profiles can be declared in Nix supplied as files or supplied by packages
        containing an already prepared profile.
      '';
      example = lib.literalExpression ''
        {
          user.databases = [
            {
              settings = {
                "org/finix/example" = {
                  enabled = true;
                };
              };
            }
          ];
        }
      '';
    };

    packages = lib.mkOption {
      type = with lib.types; listOf package;
      default = [ ];
      description = ''
        Packages providing dconf profiles or databases under `/etc/dconf`.
      '';
    };
  };

  config = lib.mkIf (cfg.enable || cfg.profiles != { }) {
    programs.dconf.packages = lib.mapAttrsToList mkDconfProfile cfg.profiles;

    environment.etc.dconf = lib.mkIf (cfg.packages != [ ]) {
      source = pkgs.symlinkJoin {
        name = "finix-dconf-system-config";
        paths = map (package: "${package}/etc/dconf") cfg.packages;
        nativeBuildInputs = [ (lib.getBin cfg.package) ];
        postBuild = ''
          if test -d $out/db; then
            dconf update $out/db
          fi
        '';
      };
    };

    services.dbus.packages = [ cfg.package ];
    environment.systemPackages = [ cfg.package ];
    security.pam.environment.GIO_EXTRA_MODULES = lib.mkIf cfg.enable {
      default = [ "${lib.getLib cfg.package}/lib/gio/modules" ];
    };
  };
}
