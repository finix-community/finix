final: prev: {
  __toString = _: "${prev.__toString or (_: "nixpkgs") prev}:Finix";

  lib = import ./lib |> prev.lib.extend;

  # TODO: upstream in nixpkgs
  finit = prev.callPackage ./finit { };

  formats = import ./pkgs-lib/formats { inherit (final) lib; pkgs = prev; };

  # see https://github.com/eudev-project/eudev/pull/290
  eudev = prev.eudev.overrideAttrs (o: {
    patches = (o.patches or [ ]) ++ [
      (final.fetchpatch {
        name = "s6-readiness.patch";
        url = "https://github.com/eudev-project/eudev/pull/290/commits/48e9923a1d0218d714989d8aec119e301aa930ae.patch";
        sha256 = "sha256-Icor2v2OYizquLW0ytYONjhCUW+oTs5srABamQR9Uvk=";
      })
    ];
  });

  nix-actor = final.callPackage ./nix-actor { };

  preserves = final.callPackage ./preserves { };

  syndicate-server = final.callPackage ./syndicate-server { };

  syndicate_utils = final.callPackage ./syndicate_utils { };

  synit-network-utils = final.callPackage ./synit-network-utils { };

  synit-pid1 = final.callPackage ./synit-pid1 { };

  synit-service = final.callPackage ./synit-service { };

  tclPackages =
    prev.tclPackages.overrideScope
      (import ./tcl-modules);

  tcl9Packages =
    (prev.tclPackages.override {
      tcl = final.tcl-9_0;
      tk = final.tk-9_0;
    }).overrideScope
      (import ./tcl-modules);

  # modern fork of sysklogd - same author as finit
  sysklogd = prev.callPackage ./sysklogd { };

  # relevant software for systems without logind - potentially useful to finix
  pam_xdg = prev.callPackage ./pam_xdg { };
}
