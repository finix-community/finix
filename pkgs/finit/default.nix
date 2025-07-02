{
  lib,
  stdenv,
  fetchFromGitHub,
  installShellFiles,
  autoreconfHook,
  pkg-config,
  libite,
  libuev,
  util-linux,
  procps,
}:

stdenv.mkDerivation {
  pname = "finit";
  version = "4.13-alpha";

  src = fetchFromGitHub {
    owner = "troglobit";
    repo = "finit";
    rev = "77404a2ea09764c3e38ba35d1e34c46e0a031819";
    hash = "sha256-UTuLEm4b2M8PQ+4Yv1n/vxD+1I+yw4IEOfMUMfz6WuQ=";
  };

  postPatch = ''
    substituteInPlace plugins/modprobe.c --replace-fail \
      '"/lib/modules"' '"/run/booted-system/kernel-modules/lib/modules"'
  '';

  nativeBuildInputs = [
    autoreconfHook
    pkg-config
    installShellFiles
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
    "--enable-urandom-plugin=no" # FIXME: causing segfault, haven't looked into why
  ];

  env.NIX_CFLAGS_COMPILE = toString [
    "-D_PATH_LOGIN=\"${util-linux}/bin/login\""
    "-DSYSCTL_PATH=\"${procps}/bin/sysctl\""
  ];

  postInstall = ''
    installShellCompletion --cmd initctl \
      --bash initctl
  '';

  meta = {
    description = "Fast init for Linux";
    mainProgram = "initctl";
    homepage = "https://troglobit.com/projects/finit/";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ aanderse ];
    platforms = lib.platforms.unix;
  };
}
