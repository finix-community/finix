{
  lib,
  stdenv,
  fetchFromGitea,
  buildNimSbom,
  pkg-config,
  tcl,
  preserves,
}:

buildNimSbom (finalAttrs: {
  outputs = [ "out" "man" ];

  src = fetchFromGitea {
    domain = "git.syndicate-lang.org";
    owner = "ehmry";
    repo = "sycl";
    rev = finalAttrs.version;
    hash = "sha256-zp2EnIY6iL3FwwmVMP8JZd5jjZ7RcBKuCQoziBTQpe8=";
  };

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    tcl
    tcl.tclPackageHook
  ];

  nimFlags = lib.optional (lib.versionOlder tcl.version "9.0") "--define:tcl8";

  env.NIX_CFLAGS_COMPILE = lib.optionalString stdenv.cc.isGNU "-Wno-error=incompatible-pointer-types";
  env.PRESERVES_SAMPLES = "${preserves}/tests/samples.bin";

  postBuild = "mv *.so src/";

  doCheck = true;
  checkPhase = ''
    runHook preCheck
    export TCLLIBPATH="$(realpath src) $TCLLIBPATH"
    pushd tests
    ${tcl}/bin/tclsh test.tcl
    popd
    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall
    install -D -t $out/lib/$name src/*.tcl src/*.so
    install -D -t $man/share/man/mann *.n.gz
    runHook postInstall
  '';

  meta = {
    description = "Syndicate Command Language";
    homepage = "https://git.syndicate-lang.org/ehmry/sycl";
    license = lib.licenses.unlicense;
    maintainers = with lib.maintainers; [ ehmry ];
  };
}) ./sbom.json
