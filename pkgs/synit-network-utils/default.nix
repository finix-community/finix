{
  lib,
  fetchFromGitea,
  stdenvNoCC,
  tcl9Packages,
  execline,
  iproute2,
  jq,
  s6-portable-utils,
}:

let
  inherit (tcl9Packages) tcl sycl;
in
stdenvNoCC.mkDerivation {
  pname = "synit-network-utils";
  version = "0.20250826";

  src = fetchFromGitea {
    domain = "git.syndicate-lang.org";
    owner = "synit";
    repo = "synit-network-utils";
    rev = "e829cbfd0690ff9c1bb7677149a6f8a3336e5a1f";
    hash = "sha256-Q+WpN/Nf0VXXbPDxxg7B+RtGD6k9EJIkoEqxnIzLpIY=";
  };

  buildInputs = [ tcl sycl ];

  buildPhase = ''
    runHook preBuild
    sed '2i lappend auto_path ${sycl}/lib/${sycl.name}' \
      <network-configurator.tcl \
      >network-configurator
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,etc,lib}

    # Install the configurator.
    install -m755 -D -t $out/bin network-configurator

    # Install the mdev hook.
    substitute "$src/mdev-hook.el" "$out/lib/mdev-hook.el" \
      --replace-fail @execlineb@ '${execline}/bin/execlineb' \
      --replace-fail @PATH@ '${
        lib.makeBinPath [
          iproute2
          jq
          s6-portable-utils
        ]
      }' \
      --replace-fail @ASSDIR@ /run/synit/config/machine \
      ;

    # Install the dhcpcd hook.
    substitute "$src/dhcpcd-hook.tcl" "$out/lib/dhcpcd-hook.tcl" \
      --replace-fail @tclsh@ '${tcl}/bin/tclsh' \
      --replace-fail @ASSDIR@ /run/synit/config/network \

    chmod +x $out/bin/* $out/lib/*

    runHook postInstall
  '';
}
