{
  lib,
  stdenv,
  fetchFromGitHub,
  autoreconfHook,
  pkg-config,
  libite,
  libuev,
  util-linux,
  procps,
}:

stdenv.mkDerivation rec {
  pname = "finit";
  version = "4.13";

  src = fetchFromGitHub {
    owner = "troglobit";
    repo = "finit";
    rev = version;
    hash = "sha256-zhgayobcfK6l8D/y/L/t8LLt7ES7vYJhnE83b04pVns=";
  };

  postPatch = ''
    substituteInPlace plugins/modprobe.c --replace-fail \
      '"/lib/modules"' '"/run/booted-system/kernel-modules/lib/modules"'
  '';

  nativeBuildInputs = [
    autoreconfHook
    pkg-config
  ];

  buildInputs = [
    libite
    libuev
  ];

  configureFlags = [
    "--sysconfdir=/etc"
    "--localstatedir=/var"

    # tweak default plugin list
    "--enable-modprobe-plugin=yes"
    "--enable-modules-load-plugin=yes"
    "--enable-hotplug-plugin=no"
  ];

  env.NIX_CFLAGS_COMPILE = toString [
    "-D_PATH_LOGIN=\"${util-linux}/bin/login\""
    "-DSYSCTL_PATH=\"${procps}/bin/sysctl\""
  ];

  meta = {
    description = "Fast init for Linux";
    mainProgram = "initctl";
    homepage = "https://troglobit.com/projects/finit/";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ aanderse ];
    platforms = lib.platforms.unix;
  };
}
