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
        mkdir -p $out
        qemu-img convert -f raw -O qcow2 \
          ${config.system.build.rawImage}/${config.image.filePath} $out/${config.image.filePath}
      '';
in
{
  imports = [ ./raw.nix ];

  config = {
    image.extension = "qcow2";

    system.build.image = lib.recursiveUpdate qcow2Image {
      passthru.filePath = config.image.filePath;
    };
  };
}
