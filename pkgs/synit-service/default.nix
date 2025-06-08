{
  lib,
  stdenvNoCC,
  tclPackages,
  installShellFiles,
  socat,
  execline,
}:

let
  inherit (tclPackages) tcl sycl;
in
stdenvNoCC.mkDerivation {
  pname = "synit-service";
  version = "1.0";

  dontUnpack = true;

  buildInputs = [ sycl ];
  nativeBuildInputs = [
    installShellFiles
  ];

  installPhase = ''
    runHook preInstall

    # Generate a custom wrapper because
    # the binary wrapper breaks somehow.
    cat << EOF > service
    #!${lib.getExe execline} -s0
    export TCLLIBPATH "''${TCLLIBPATH}"
    export PATH "${lib.makeBinPath [ socat ]}"
    ${tcl}/bin/tclsh ${./service.tcl} \$@
    EOF


    install -m755 -D -t $out/bin service
    installShellCompletion --fish --cmd service ${./completions.fish}
    runHook postInstall
  '';

  meta = {
    description = "Synit service management utility";
    maintainers = with lib.maintainers; [ ehmry ];
    mainProgram = "service";
    license = lib.licenses.unlicense;
  };
}
