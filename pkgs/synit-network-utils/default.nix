{
  lib,
  fetchFromGitea,
  stdenvNoCC,
  tcl-9_0,
  tclPackages,
  execline,
  iproute2,
  jq,
  s6-portable-utils,
}:

let
  # Nixpkgs is using Tcl-8 instead of Tcl-9.
  tclPackages' = tclPackages.overrideScope (_: _: { tcl = tcl-9_0; });
  inherit (tclPackages') tcl sycl;
in
stdenvNoCC.mkDerivation {
  pname = "synit-network-utils";
  version = "1";

  src = fetchFromGitea {
    domain = "git.syndicate-lang.org";
    owner = "synit";
    repo = "synit-network-utils";
    rev = "a9361461ef525ba0082d770adb31455273df1d3d";
    hash = "sha256-394+8w/WVG/GXMXreBsQeGkCfY2hnzGkgmnXmloWRiI=";
  };

  buildInputs = [ sycl ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/{bin,etc,lib}

    # Install the network-configurator actor with a wrapper script
    # that exports the TCLLIBPATH of the build environment.
    cp $src/network-configurator.tcl $out/lib/network-configurator.tcl
    cat << EOF > $out/bin/network-configurator
    #!${execline}/bin/execlineb -s0
    export TCLLIBPATH "''${TCLLIBPATH}"
    ${tcl}/bin/tclsh $out/lib/network-configurator.tcl \$@
    EOF

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
