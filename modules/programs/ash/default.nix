{ config, lib, pkgs, ... }:

let
  cfg = config.programs.ash;

  ashPackage = (pkgs.pkgsStatic.busybox.override {
    enableMinimal = true;
    extraConfig = ''
      CONFIG_ASH y
      CONFIG_ASH_OPTIMIZE_FOR_SIZE y
      CONFIG_ASH_INTERNAL_GLOB y
      CONFIG_ASH_BASH_COMPAT y
      CONFIG_ASH_JOB_CONTROL y
      CONFIG_ASH_ALIAS y
      CONFIG_ASH_GETOPTS y
      CONFIG_ASH_BUILTIN_ECHO y
      CONFIG_SH_IS_ASH y
      CONFIG_BASH_IS_NONE y

      CONFIG_AWK n
      CONFIG_GREP n
      CONFIG_SED n
      CONFIG_CAT n
      CONFIG_LS n
      CONFIG_CP n
      CONFIG_MV n
      CONFIG_RM n
      CONFIG_MKDIR n
      CONFIG_RMDIR n
    '';
  }).overrideAttrs (old: {
    pname = "ash";
    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      cp busybox $out/bin/ash
      strip -s $out/bin/ash
      ln -s ash $out/bin/sh
      runHook postInstall
    '';
    meta = (old.meta or {}) // {
      description = "Almquist shell (ash) optimized for size";
      mainProgram = "ash";
    };
  });
in
{
  options.programs.ash = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable ash as a system shell.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = ashPackage;
      defaultText = lib.literalExpression "pkgsStatic.busybox (minimal ash)";
      description = "The package to use for `ash`.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    environment.shells = [
      "/run/current-system/sw/bin/ash"
      "${cfg.package}/bin/ash"
    ];
  };
}
