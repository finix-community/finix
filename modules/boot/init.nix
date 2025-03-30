{ config, pkgs, lib, ... }:
let
  # finit needs to mount extra file systems not covered by boot
  fsPackages = config.boot.supportedFilesystems
    |> lib.filterAttrs (_: v: v.enable)
    |> lib.attrValues
    |> lib.catAttrs "packages"
    |> lib.flatten
    |> lib.unique
  ;
in
{
  # TODO: something not quite sitting right with me here
  options.boot.init = {
    script = lib.mkOption {
      type = lib.types.path;
    };
  };

  config.boot.init.script = pkgs.writeScript "init" ''
    #!${pkgs.runtimeShell}

    systemConfig='@systemConfig@'

    echo
    echo "[1;32m<<< finix - stage 2 >>>[0m"
    echo

    echo "running activation script..."
    $systemConfig/activate

    # record the boot configuration.
    ${pkgs.coreutils}/bin/ln -sfn "$systemConfig" /run/booted-system

    # finit requires fsck, modprobe & mount commands before PATH can be read from finit.conf
    export PATH=${lib.makeBinPath ([ pkgs.unixtools.fsck pkgs.kmod pkgs.util-linux.mount ] ++ fsPackages)}

    echo "about to launch finit"
    exec ${config.finit.package}/bin/finit "$@"
  '';
}
