{ config, lib, pkgs, ... }:
let
  inherit (config.security) wrapperDir wrappers;

  useSetuid = config.security.wrapperMethod == "setuid";

  parentWrapperDir = dirOf wrapperDir;

  # This is security-sensitive code, and glibc vulns happen from time to time.
  # musl is security-focused and generally more minimal, so it's a better choice here.
  # The dynamic linker is still a fairly complex piece of code, and the wrappers are
  # quite small, so linking it statically is more appropriate.
  securityWrapper = sourceProg : pkgs.pkgsStatic.callPackage ./wrapper.nix {
    inherit sourceProg;

    # glibc definitions of insecure environment variables
    #
    # We extract the single header file we need into its own derivation,
    # so that we don't have to pull full glibc sources to build wrappers.
    #
    # They're taken from pkgs.glibc so that we don't have to keep as close
    # an eye on glibc changes. Not every relevant variable is in this header,
    # so we maintain a slightly stricter list in wrapper.c itself as well.
    unsecvars = lib.overrideDerivation (pkgs.srcOnly pkgs.glibc)
      ({ name, ... }: {
        name = "${name}-unsecvars";
        installPhase = ''
          mkdir $out
          cp sysdeps/generic/unsecvars.h $out
        '';
      });
  };

  ###### Activation script for the setcap wrappers
  mkSetcapProgram =
    { program
    , capabilities
    , source
    , owner
    , group
    , permissions
    , ...
    }:
    ''
      install -m 0000 -o ${owner} -g ${group} \
        ${securityWrapper source}/bin/security-wrapper \
        "$wrapperDir/${program}"

      # Set desired capabilities on the file plus cap_setpcap so
      # the wrapper program can elevate the capabilities set on
      # its file into the Ambient set.
      ${pkgs.libcap.out}/bin/setcap "cap_setpcap,${capabilities}" "$wrapperDir/${program}"

      # Set the executable bit
      chmod ${permissions} "$wrapperDir/${program}"
    '';

  ###### Activation script for the setuid wrappers
  mkSetuidProgram =
    { program
    , source
    , owner
    , group
    , setuid
    , setgid
    , permissions
    , ...
    }:
    ''
      install -m 0000 -o ${owner} -g ${group} \
        ${securityWrapper source}/bin/security-wrapper \
        "$wrapperDir/${program}"

      chmod "u${if setuid then "+" else "-"}s,g${if setgid then "+" else "-"}s,${permissions}" "$wrapperDir/${program}"
    '';

  mkWrappedPrograms =
    builtins.map
      (opts:
        if opts.capabilities != ""
        then mkSetcapProgram opts
        else mkSetuidProgram opts
      ) (lib.attrValues wrappers);

  wrappersScript = pkgs.writeShellScript "suid-sgid-wrappers.sh" ''
      set -e
      # We want to place the tmpdirs for the wrappers to the parent dir.
      mkdir -p "${parentWrapperDir}"
      wrapperDir=$(mktemp --directory --tmpdir="${parentWrapperDir}" wrappers.XXXXXXXXXX)
      chmod a+rx "$wrapperDir"

      ${lib.concatStringsSep "\n" mkWrappedPrograms}

      if [ -L ${wrapperDir} ]; then
        # Atomically replace the symlink
        # See https://axialcorps.com/2013/07/03/atomically-replacing-files-and-directories/
        old=$(readlink -f ${wrapperDir})
        if [ -e "${wrapperDir}-tmp" ]; then
          rm --force --recursive "${wrapperDir}-tmp"
        fi
        ln --symbolic --force --no-dereference "$wrapperDir" "${wrapperDir}-tmp"
        mv --no-target-directory "${wrapperDir}-tmp" "${wrapperDir}"
        rm --force --recursive "$old"
      else
        # For initial setup
        ln --symbolic "$wrapperDir" "${wrapperDir}"
      fi
    '';

in
{
  config = lib.mkIf useSetuid {

    security.wrapperDir = "/run/wrappers/bin";

    fileSystems."/run/wrappers" = {
      fsType = "tmpfs";
      options = [ "nodev" "mode=755" "size=50%" "X-mount.mkdir" ];
    };

    finit.tasks.suid-sgid-wrappers = {
      description = "create suid/sgid wrappers";
      runlevels = "S12345";
      log = true;
      command = wrappersScript;
    };

    synit.daemons.suid-sgid-wrappers = {
      argv = [ wrappersScript ];
      path = [ pkgs.coreutils ];
      restart = "on-error";
      logging.enable = lib.mkDefault false;
      provides = [ [ "milestone" "wrappers" ] ];
    };
  };
}
