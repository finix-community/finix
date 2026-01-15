{
  config,
  pkgs,
  lib,
  ...
}:
let
  scriptOpts = {
    options = {
      deps = lib.mkOption {
        type = with lib.types; listOf str;
        default = [ ];
        description = "List of dependencies. The script will run after these.";
      };
      text = lib.mkOption {
        type = lib.types.lines;
        description = "The content of the script.";
      };
    };
  };
  checkAssertWarn = lib.asserts.checkAssertWarn config.assertions config.warnings;
in
{
  options.system.topLevel = lib.mkOption {
    type = lib.types.path;
    description = "top-level system derivation";
    readOnly = true;
  };

  options.system.activation = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };

    scripts = lib.mkOption {
      type = with lib.types; attrsOf (coercedTo str lib.noDepEntry (submodule scriptOpts));
      default = { };

      example = lib.literalExpression ''
        { stdio.text =
          '''
            # Needed by some programs.
            ln -sfn /proc/self/fd /dev/fd
            ln -sfn /proc/self/fd/0 /dev/stdin
            ln -sfn /proc/self/fd/1 /dev/stdout
            ln -sfn /proc/self/fd/2 /dev/stderr
          ''';
        }
      '';

      description = ''
        A set of shell script fragments that are executed when a NixOS
        system configuration is activated.  Examples are updating
        /etc, creating accounts, and so on.  Since these are executed
        every time you boot the system or run
        {command}`nixos-rebuild`, it's important that they are
        idempotent and fast.
      '';
    };

    path = lib.mkOption {
      type = with lib.types; listOf package;
      default = [ ];
    };

    out = lib.mkOption {
      type = lib.types.path;
      description = "the actual script to run on activation....";
      readOnly = true;
    };
  };

  config = {
    system.activation.out =
      let
        set' = lib.mapAttrs (
          a: v:
          v
          // {
            text = ''
              #### Activation script snippet ${a}:
              _localstatus=0
              ${v.text}

              if (( _localstatus > 0 )); then
                printf "Activation script snippet '%s' failed (%s)\n" "${a}" "$_localstatus"
              fi
            '';
          }
        ) config.system.activation.scripts;
      in
      pkgs.writeScript "activate" ''
        #!${pkgs.runtimeShell}

        systemConfig='@systemConfig@'

        export PATH=/empty
        for i in ${toString config.system.activation.path}; do
            PATH=$PATH:$i/bin:$i/sbin
        done

        _status=0
        trap "_status=1 _localstatus=\$?" ERR

        # Ensure a consistent umask.
        umask 0022

        ${lib.textClosureMap lib.id set' (lib.attrNames set')}

        # Make this configuration the current configuration.
        # The readlink is there to ensure that when $systemConfig = /system
        # (which is a symlink to the store), /run/current-system is still
        # used as a garbage collection root.
        ln -sfn "$(readlink -f "$systemConfig")" /run/current-system

        exit $_status
      '';

    system.activation.scripts.specialfs = ''
      echo "specialfs stub here..."
      mkdir -p /bin /etc /run /tmp /usr /var/{cache,db,empty,lib,log,spool}
      s6-ln -s -f -n /run /var/run
    '';

    system.activation.path =
      with pkgs;
      map lib.getBin [
        coreutils
        gnugrep
        findutils
        getent
        stdenv.cc.libc # nscd in update-users-groups.pl
        shadow
        nettools # needed for hostname
        util-linux # needed for mount and mountpoint
        s6-portable-utils # s6-ln
      ];

    system.topLevel = checkAssertWarn (
      pkgs.stdenvNoCC.mkDerivation {
        name = "finix-system";
        preferLocalBuild = true;
        allowSubstitutes = false;
        buildCommand = ''
          mkdir -p $out $out/bin

          echo -n "finix" > $out/nixos-version

          cp ${config.system.activation.out} $out/activate
          cp ${config.boot.init.script} $out/init

          ${pkgs.coreutils}/bin/ln -s ${config.environment.path} $out/sw

          substituteInPlace $out/activate --subst-var-by systemConfig $out
          substituteInPlace $out/init --subst-var-by systemConfig $out

          mkdir $out/specialisation

          ${lib.concatMapAttrsStringSep "\n" (
            k: v: "ln -s ${v.system.topLevel} $out/specialisation/${lib.escapeShellArg k}"
          ) config.specialisation}
        ''
        + lib.optionalString config.boot.kernel.enable ''
          ${pkgs.coreutils}/bin/ln -s ${config.boot.kernelPackages.kernel}/bzImage $out/kernel
          ${pkgs.coreutils}/bin/ln -s ${config.system.modulesTree} $out/kernel-modules
          ${pkgs.coreutils}/bin/ln -s ${config.hardware.firmware}/lib/firmware $out/firmware
        ''
        + lib.optionalString config.boot.initrd.enable ''
          ${pkgs.coreutils}/bin/ln -s ${config.boot.initrd.package}/initrd $out/initrd
        ''
        + lib.optionalString config.finit.enable ''
          cp ${../../finit/switch-to-configuration.sh} $out/bin/switch-to-configuration
          substituteInPlace $out/bin/switch-to-configuration \
            --subst-var out \
            --subst-var-by bash ${pkgs.bash} \
            --subst-var-by distroId finix \
            --subst-var-by finit ${config.finit.package} \
            --subst-var-by installHook ${config.providers.bootloader.installHook}
        ''
        + lib.optionalString config.boot.bootspec.enable ''
          ${config.boot.bootspec.writer}
        ''
        + lib.optionalString (config.boot.bootspec.enable && config.boot.bootspec.enableValidation) ''
          ${config.boot.bootspec.validator} "$out/${config.boot.bootspec.filename}"
        '';
      }
    );
  };
}
