{
  lib,
  stdenv,
  fetchFromGitHub,
  autoreconfHook,
  pkg-config,
}:

stdenv.mkDerivation rec {
  pname = "sysklogd";
  version = "2.7.1";

  src = fetchFromGitHub {
    owner = "troglobit";
    repo = "sysklogd";
    rev = "v${version}";
    hash = "sha256-Y52pPzvbxKrHWKwzgnlg0j3kjqUNWbIYL0Y4Wy4ywoY=";
  };

  nativeBuildInputs = [
    autoreconfHook
    pkg-config
  ];

  configureFlags = [
    "--sysconfdir=/etc"
    "--localstatedir=/var"
  ];

  meta = {
    description = "BSD syslog daemon with syslog()/syslogp() API replacement for Linux, RFC3164 + RFC5424";
    homepage = "https://troglobit.com/projects/sysklogd/";
    license = lib.licenses.bsd3;
    maintainers = with lib.maintainers; [ aanderse ];
    platforms = lib.platforms.unix;
  };
}
