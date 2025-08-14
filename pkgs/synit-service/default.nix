{
  lib,
  stdenvNoCC,
  fetchFromGitea,
  tcl9Packages,
  installShellFiles,
}:

let
  inherit (tcl9Packages) tcl sycl;
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "synit-service";
  version = "0.1";

  src = fetchFromGitea {
    domain = "git.syndicate-lang.org";
    owner = "synit";
    repo = "synit-service";
    rev = finalAttrs.version;
    hash = "sha256-kZRGzNmTyRTzYmZGXtdIf6qC8CyoOCDRg4mQvvXbdzM=";
  };

  buildInputs = [
    tcl
    sycl
  ];

  nativeBuildInputs = [
    installShellFiles
  ];

  buildPhase = ''
    runHook preBuild
    sed '2i lappend auto_path ${sycl}/lib/${sycl.name}' <service.tcl >service
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -m755 -D -t $out/bin service
    installShellCompletion --fish --cmd service completions/service.fish
    runHook postInstall
  '';

  meta = {
    description = "Synit service management utility";
    maintainers = with lib.maintainers; [ ehmry ];
    mainProgram = "service";
    license = lib.licenses.unlicense;
  };
})
