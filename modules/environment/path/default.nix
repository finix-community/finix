{
  config,
  pkgs,
  lib,
  ...
}:
let
  corePackages = lib.mapAttrs (_: lib.mkDefault) (
    with pkgs;
    {
      inherit
        acl
        attr
        cpio
        curl
        diffutils
        findutils
        getent
        getconf
        less
        libcap
        ncurses
        mkpasswd
        netcat
        procps
        su
        time
        util-linux
        which
        zstd
        bashInteractive
        gnugrep
        gnused
        gnutar
        ;

      # If package name won't match key, we can do:
      # grep = busybox;
    }
  );
in
{
  options = {
    environment.systemPackages = lib.mkOption {
      type = with lib.types; listOf package;
      default = { };
    };

    environment.packageSet = lib.mkOption {
      type = with lib.types; attrsOf (nullOr package);
      default = { };
      description = ''
        Experimental option, where packages are defined as an attribute set.
        Follows format "environment.packageSet.foo = lib.mkDefault pkgs.foo | null;".

        Expands into "environment.systemPackages", but this
        format allows to remove packages from system closure in a targeted manner.
      '';
    };

    environment.pathsToLink = lib.mkOption {
      type = with lib.types; listOf str;
      default = [ ];
      example = [ "/" ];
      description = "List of directories to be symlinked in {file}`/run/current-system/sw`.";
    };

    environment.extraSetup = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Shell fragments to be run after the system environment has been created. This should only be used for things that need to modify the internals of the environment, e.g. generating MIME caches. The environment being built can be accessed at $out.";
    };

    environment.path = lib.mkOption {
      type = lib.types.path;
      readOnly = true;
    };
  };

  config = {
    environment.packageSet = corePackages;
    environment.systemPackages = lib.mkMerge [
      (with pkgs; [ ])

      (lib.mkAfter (
        lib.unique (lib.filter (pkg: pkg != null) (lib.attrValues config.environment.packageSet))
      ))
    ];

    environment.pathsToLink = [
      "/bin"
      "/etc/xdg"
      "/etc/gtk-2.0"
      "/etc/gtk-3.0"
      # NOTE: We need `/lib' to be among `pathsToLink' for NSS modules to work.
      "/lib" # FIXME: remove and update debug-info.nix
      "/sbin"

      # TODO: trim this list down
      "/share/emacs"
      "/share/hunspell"
      "/share/org"
      "/share/themes"
      "/share/vulkan"
      "/share/kservices5"
      "/share/kservicetypes5"
      "/share/kxmlgui5"
      "/share/thumbnailers"
      "/share/wayland-sessions"
    ];

    environment.path = pkgs.buildEnv {
      name = "system-path";
      paths = config.environment.systemPackages;
      pathsToLink = config.environment.pathsToLink;

      ignoreCollisions = true;

      # !!! Hacky, should modularise.
      # outputs TODO: note that the tools will often not be linked by default
      postBuild = ''
        # Remove wrapped binaries, they shouldn't be accessible via PATH.
        find $out/bin -maxdepth 1 -name ".*-wrapped" -type l -delete

        if [ -x $out/bin/glib-compile-schemas -a -w $out/share/glib-2.0/schemas ]; then
            $out/bin/glib-compile-schemas $out/share/glib-2.0/schemas
        fi

        ${config.environment.extraSetup}
      '';
    };
  };
}
