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
    rev = "8be7a462e0e8cae4afabe1482dd03f8aba39c59d";
    hash = "sha256-RsoXcEmhro0YigYXF/jO5yG6YMBtX2ePekUX8e7rFII=";
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
