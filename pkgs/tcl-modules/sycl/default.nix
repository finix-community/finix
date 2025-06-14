{
  lib,
  fetchFromGitea,
  buildNimSbom,
  tcl,
  enableDebug ? false
}:

buildNimSbom {
  pname = "sycl";

  src = fetchFromGitea {
    domain = "git.syndicate-lang.org";
    owner = "ehmry";
    repo = "sycl";
    rev = "501afd7cbada77ba1912065efb98b5de9d46e8de";
    hash = "sha256-YSBt7V+8uVEMZtwiNIHJ55tFss2El7daYbSpKMALryI=";
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
