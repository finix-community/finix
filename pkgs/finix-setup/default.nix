{
  lib,
  stdenv,
  finit,
  libite,
  libuev,
  kmod,
  util-linux,
  unixtools,
}:
let
  # finit requires fsck, modprobe & mount commands before PATH can be read from finit.conf
  PATH = lib.makeBinPath [
    kmod
    unixtools.fsck
    util-linux.mount
  ];
in
stdenv.mkDerivation {
  pname = "finix-setup";
  version = "0.1.0";

  src = ./.;

  buildInputs = [
    finit
    libite
    libuev
  ];

  buildPhase = ''
    runHook preBuild

    # substitute the initial PATH for finit to use
    substituteInPlace finix-setup.c \
      --replace-fail '@initialPath@' "${PATH}"

    # compile the plugin as a shared library
    # flags based on finit-plugins build system
    $CC -shared -fPIC \
      -W -Wall -Wextra -Wno-unused-parameter -std=gnu99 \
      -D__FINIT__ \
      -I${finit.dev}/include \
      -o finix-setup.so \
      finix-setup.c

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/finit/plugins
    install -m 755 finix-setup.so $out/lib/finit/plugins/

    runHook postInstall
  '';

  meta = {
    description = "finit plugin for finix early boot initialization";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
