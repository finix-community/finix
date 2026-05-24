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
  version = "0.2-unstable-2026-06-03";

  __structuredAttrs = true;

  src = fetchFromCodeberg {
    owner = "Gardenhouse";
    repo = "gardendevd";
    rev = "7e58bbd06dfab8a47b6f512eee802a23de79d890";
    sha256 = "sha256-VecujIPKfKQN4EnQ+zCbUW8nN0/+ftsdIGNJUyMyPfY=";
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
    "-Dopenrc=disabled"
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
    description = "udev daemon running on top of mdevd to replace systemd-udev";
    maintainers = with lib.maintainers; [
      aanderse
      choco98
    ];
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
  };
})
