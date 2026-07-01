{
  lib,
  stdenv,
  fetchFromCodeberg,
  acl,
  elogind,
  meson,
  ninja,
  pkg-config,
  util-linux,
  kmod,
  uaccessSupport ? true,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "gardendevd";
  version = "0.2-unstable-2026-06-28";

  __structuredAttrs = true;

  src = fetchFromCodeberg {
    owner = "Gardenhouse";
    repo = "gardendevd";
    rev = "a3f5ec34211b2dc71f8d63624522002ceb295a7a";
    hash = "sha256-kVbaJ3Btk428s3pabAVXvy0X3Tx02kE6zwd1uO8N6ik=";
  };

  strictDeps = true;

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
  ];

  buildInputs = lib.optionals uaccessSupport [
    acl
    elogind
  ];

  mesonFlags = [
    "-Ddracut=disabled"
    "-Dmdevd=enabled"
    "-Duaccess=${if uaccessSupport then "enabled" else "disabled"}"
  ];

  postPatch = ''
    substituteInPlace src/rules-builtin.c \
      --replace '/sbin/blkid' '${util-linux}/bin/blkid' \
      --replace '/sbin/modprobe' '${kmod}/bin/modprobe'
    substituteInPlace src/rules-parse.c \
      --replace '/usr/lib/udev/rules.d' "$out/lib/udev/rules.d"
    substituteInPlace src/spawn.c \
      --replace '/usr/lib/udev/' "$out/lib/udev/"

    patchShebangs scripts/
  '';

  meta = {
    homepage = "https://codeberg.org/Gardenhouse/gardendevd";
    description = "udev-compatible daemon designed to be a lightweight and flexible alternative to systemd-udevd.";
    maintainers = with lib.maintainers; [
      aanderse
      choco98
    ];
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
  };
})
