{
  lib,
  stdenv,
  fetchFromGitHub,
  pkg-config,
  logindSupport ? true,
  systemd,
  coreutils,
  udevSupport ? true,
  udevCheckHook,
}:

stdenv.mkDerivation rec {
  pname = "brightnessctl";
  version = "0.5.1+";

  src = fetchFromGitHub {
    owner = "Hummer12007";
    repo = "brightnessctl";
    rev = "e70bc55cf053caa285695ac77507e009b5508ee3";
    sha256 = "sha256-agteP/YPlTlH8RwJ9P08pwVYY+xbHApv9CpUKL4K0U0=";
  };

  postPatch = ''
    substituteInPlace 90-brightnessctl.rules \
      --replace-fail /bin/ ${coreutils}/bin/
  '';

  configureFlags = [
    "--install-mode=0755"
  ] ++ lib.optionals (!logindSupport) [
    "--disable-logind"
  ] ++ lib.optionals (!udevSupport) [
    "--disable-udev"
  ];

  makeFlags = [
    "PREFIX="
    "DESTDIR=$(out)"
  ];

  nativeBuildInputs = [
    pkg-config
  ] ++ lib.optionals udevSupport [
    udevCheckHook
  ];

  buildInputs = lib.optionals logindSupport [ systemd ];

  doInstallCheck = true;

  meta = with lib; {
    homepage = "https://github.com/Hummer12007/brightnessctl";
    description = "This program allows you read and control device brightness";
    license = licenses.mit;
    maintainers = with maintainers; [ megheaiulian ];
    platforms = platforms.linux;
    mainProgram = "brightnessctl";
  };

}
