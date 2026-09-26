{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.sh;
in
{
  imports = [
    (lib.mkRemovedOptionModule [ "environment" "binsh" ]
      "use programs.sh.package instead - this option takes a package instead of a path to an executable"
    )
  ];

  options.programs.sh.package = lib.mkOption {
    type = lib.types.package;
    default = pkgs.dash;
    defaultText = lib.literalExpression "pkgs.dash";
    example = lib.literalExpression ''
      pkgs.busybox.overrideAttrs (o: {
        meta = o.meta // { mainProgram = "ash"; };
      });
    '';
    description = ''
      Default shell linked system-wide to `/bin/sh`. Ensure any
      modifications to this shell are POSIX-compliant.
    '';
  };

  config = {
    system.activation.scripts.binsh = ''
      mkdir -p -m 0755 /bin

      # required /bin/sh symlink
      ln -sfn "${lib.getExe cfg.package}" /bin/sh
    '';
  };
}
