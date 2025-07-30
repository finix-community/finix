{
  lib,
  fetchFromGitea,
  buildNimSbom,
  tcl,
  enableDebug ? false
}:

buildNimSbom {
  pname = "sycl";
  version = "2.1";

  src = fetchFromGitea {
    domain = "git.syndicate-lang.org";
    owner = "ehmry";
    repo = "sycl";
    rev = "16d3fc3e991e260391ffdaad96e0a6c6f9c12019";
    hash = "sha256-yx1QZ+dNc99AtfZgL3DIcN43G+DudwLmJylXWUG8cHQ=";
  };

  nativeBuildInputs = [
    tcl.tclPackageHook
  ];
  buildInputs = [
    tcl
  ];

  postPatch = lib.optionalString enableDebug ''
    substituteInPlace src/syndicate.tcl \
      --replace-fail ' # puts stderr ' ' puts stderr '
  '';

  installPhase = ''
    runHook preInstall
    install -D -t $out/lib/$name src/*.tcl libdataspaces.so
    install -D -t $out/share/man/mann *.n.gz
    runHook postInstall
  '';

  meta = {
    description = "Syndicate Command Language";
    homepage = "https://git.syndicate-lang.org/ehmry/sycl";
    license = lib.licenses.unlicense;
    maintainers = with lib.maintainers; [ ehmry ];
  };
} ./sbom.json
