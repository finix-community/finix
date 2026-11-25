{
  lib,
  pkgs,
  kernelTarget,
  initrdTarget,
  topLevel,
  kernelParams,
}:
pkgs.writeText "limine.conf" ''
  timeout: 0

  /finix
  protocol: linux
  kernel_path: boot():${kernelTarget}
  cmdline: ${lib.concatStringsSep " " ([ "init=${topLevel}/init" ] ++ kernelParams)}
  module_path: boot():${initrdTarget}
''
