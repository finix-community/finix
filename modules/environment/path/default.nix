{ config, pkgs, lib, ... }:
{
  options = {
    environment.systemPackages = lib.mkOption {
      type = with lib.types; listOf package;
      default = { };
    };

    environment.pathsToLink = lib.mkOption {
      type = with lib.types; listOf str;
      default = [];
      example = ["/"];
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
    environment.systemPackages = with pkgs; [
      acl
      attr
      bzip2
      cpio
      curl
      diffutils
      findutils
      getent
      getconf
      gzip
      xz
      less
      libcap
      ncurses
      netcat
      mkpasswd
      procps
      su
      time
      util-linux
      which
      zstd

      bashInteractive
      coreutils-full
      gawk
      gnugrep
      gnupatch
      gnused
      gnutar
    ];

    environment.pathsToLink =
      [ "/bin"
        "/etc/xdg"
        "/etc/gtk-2.0"
        "/etc/gtk-3.0"
        # NOTE: We need `/lib' to be among `pathsToLink' for NSS modules to work.
        "/lib" # FIXME: remove and update debug-info.nix
        "/sbin"
        "/share/emacs"
        "/share/hunspell"
        "/share/org"
        "/share/themes"
        "/share/vulkan"
        "/share/kservices5"
        "/share/kservicetypes5"
        "/share/kxmlgui5"
        "/share/thumbnailers"
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
