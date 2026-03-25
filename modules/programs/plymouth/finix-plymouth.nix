{
  lib,
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation {
  pname = "finix-plymouth";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "finix-community";
    repo = "plymouth";
    rev = "95870aeefa761f11c9004e15e465accd8dc96dd9";
    hash = "sha256-3aFGpL08sgXzea1bD82YHuxGJBAwtvYCCOJTlB/TaY4=";
  };

  dontBuild = true;

  installPhase = ''
    make install PREFIX=$out/share DESTDIR=
  '';

  meta = {
    description = "Finix Plymouth boot theme";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ aanderse ];
    platforms = lib.platforms.linux;
  };
}
