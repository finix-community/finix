{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.ash;

  package =
    pkgs.runCommand "ash-${cfg.package.version}"
      {
        meta = cfg.package.meta // {
          mainProgram = "ash";
        };
        passthru = { inherit (cfg.package) shellPath; };
      }
      ''
        mkdir -p $out/bin
        ln -s ${lib.getExe' cfg.package "ash"} $out${cfg.package.shellPath}
      '';
in
{
  options.programs.ash = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [ash](${pkgs.busybox.meta.homepage}) as a system shell.
      '';
    };

    package = lib.mkOption {
      type = lib.types.shellPackage;
      default = pkgs.busybox;
      defaultText = lib.literalExpression "pkgs.busybox";
      description = ''
        The package to use for `ash`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ package ];
    environment.shells = [
      "/run/current-system/sw${package.shellPath}"
      "${package}${package.shellPath}"
    ];
  };
}
