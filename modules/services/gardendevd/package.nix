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
  version = "0.2";

  __structuredAttrs = true;

  src = fetchFromCodeberg {
    owner = "Gardenhouse";
    repo = "gardendevd";
    tag = "v${finalAttrs.version}";
    sha256 = "sha256-8G6Omeia1W+4dZOVHGtY/9CnKEpqD2x/W8Zkjt7fK/Q=";
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
    "-Dopenrc=false"
    "-Dmdevd=true"
    "-Duaccess=${lib.boolToString uaccessSupport}"
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
