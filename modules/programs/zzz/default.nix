{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.zzz;
in
{
  imports = [
    ./providers.resume-and-suspend.nix
  ];

  options.programs.zzz = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [zzz](${cfg.package.meta.homepage}).
      '';
    };

    # nixpkgs PR: https://github.com/NixOS/nixpkgs/pull/460833
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage (
        {
          stdenv,
          lib,
          fetchFromGitHub,
          asciidoctor,
        }:
        stdenv.mkDerivation rec {
          pname = "zzz";
          version = "0.2.0";

          src = fetchFromGitHub {
            owner = "jirutka";
            repo = "zzz";
            rev = "v${version}";
            sha256 = "sha256-gm/fzhgGM2kns051PKY223uesctvMj9LmLc4btUsTt8=";
          };

          postPatch = ''
            substituteInPlace zzz.c --replace-fail \
              'setenv("PATH", "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin", 1);' 'setenv("PATH", "/run/wrappers/bin:/run/current-system/sw/bin", 1);'
          '';

          nativeBuildInputs = [ asciidoctor ];

          makeFlags = [
            "prefix=$(out)"
            "sysconfdir=$(out)/etc"
          ];

          meta = {
            description = "A simple program to suspend or hibernate your computer";
            mainProgram = "zzz";
            homepage = "https://github.com/jirutka/zzz";
            license = lib.licenses.mit;
            maintainers = with lib.maintainers; [ aanderse ];
            platforms = lib.platforms.linux;
          };
        }
      ) { };
      description = ''
        The package to use for `zzz`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    # this module supplies an implementation for `providers.resumeAndSuspend`
    providers.resumeAndSuspend.backend = "zzz";
  };
}
