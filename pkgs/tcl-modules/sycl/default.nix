{
  lib,
  stdenv,
  fetchFromGitea,
  buildNimSbom,
  pkg-config,
  tcl-9_0,
  preserves,
}:
let
  tcl = tcl-9_0;
in
buildNimSbom (finalAttrs: {
  src = fetchFromGitea {
    domain = "git.syndicate-lang.org";
    owner = "ehmry";
    repo = "sycl";
    tag = finalAttrs.version;
    hash = "sha256-LQLTSZucGrIVzUwVGVNfolOsbaCERWqlwZCMvVW36WU=";
  };

  nativeBuildInputs = [
    pkg-config
    tcl.tclPackageHook
  ];

  buildInputs = [
    tcl
  ];

  env.NIX_CFLAGS_COMPILE = lib.optionalString stdenv.cc.isGNU "-Wno-error=incompatible-pointer-types";

  postBuild = "mv *.so src/";

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    export TCLLIBPATH="$(realpath src) $TCLLIBPATH"
    pushd tests
    ${tcl}/bin/tclsh preserves.test -verbose bps <${preserves}/tests/samples.bin
    ${tcl}/bin/tclsh syndicate.test -verbose bps
    popd
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -D -t $out/lib/$name src/*.tcl src/*.so
    install -D -t $out/share/man/mann *.n.gz
    runHook postInstall
  '';

  meta = {
    description = "Syndicate Command Language";
    homepage = "https://git.syndicate-lang.org/ehmry/sycl";
    license = lib.licenses.unlicense;
    maintainers = with lib.maintainers; [ ehmry ];
  };
}) ./sbom.json
