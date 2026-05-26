{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.v2rayn;
  v2rayn-pkg = cfg.package.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];
    postInstall = (old.postInstall or "") + ''
      wrapProgram $out/bin/v2rayN \
        --run 'mkdir -p "$HOME/.local/share/v2rayN/bin/xray" "$HOME/.local/share/v2rayN/bin/sing_box"' \
        --run 'ln -sf ${lib.getExe pkgs.xray}  "$HOME/.local/share/v2rayN/bin/xray/xray"' \
        --run 'ln -sf ${lib.getExe pkgs.sing-box} "$HOME/.local/share/v2rayN/bin/sing_box/sing-box"'
    '';
  });
in
{
  options.programs.v2rayn = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [v2rayn](${pkgs.v2rayn}).
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.v2rayn;
      defaultText = lib.literalExpression "pkgs.v2rayn";
      description = ''
        The package to use for `v2rayn`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      v2rayn-pkg
    ];
  };
}
