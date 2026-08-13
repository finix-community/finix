{ lib, pkgs, ... }:
{
  options = {
    programs.sed.package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.gnused;
    };

    programs.grep.package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.gnugrep;
    };

    programs.tar.package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.gnutar;
    };

    programs.which.package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.which;
    };

    programs.utilLinux.package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.util-linux;
    };

    programs.findUtils.package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.findutils;
    };
  };
}
