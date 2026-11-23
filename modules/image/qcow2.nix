{
  config,
  lib,
  pkgs,
  ...
}:
let
  qcow2Image =
    pkgs.runCommand "finix-${config.image.fileName}"
      {
        nativeBuildInputs = [ pkgs.qemu-utils ];
      }
      ''
        ${lib.getExe' pkgs.qemu-utils "qemu-img"} convert -f raw -O qcow2 \
          ${config.system.build.rawImage} $out
      '';
in
{
  imports = [ ./raw.nix ];

  config = {
    image.extension = lib.mkOverride 50 "qcow2";

    system.build.image = lib.mkOverride 50 (
      lib.recursiveUpdate qcow2Image {
        passthru.filePath = config.image.filePath;
      }
    );
  };
}
