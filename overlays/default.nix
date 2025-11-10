final: prev: {
  __toString = _: "${prev.__toString or (_: "nixpkgs") prev}:Finix";

  lib = import ../pkgs/lib |> prev.lib.extend;

  formats = import ../pkgs/pkgs-lib/formats {
    inherit (final) lib;
    pkgs = prev;
  };

  finix-rebuild = final.callPackage ../pkgs/finix-rebuild { };

  nix-actor = final.callPackage ../pkgs/nix-actor { };

  preserves = final.callPackage ../pkgs/preserves { };

  syndicate-server = final.callPackage ../pkgs/syndicate-server { };

  syndicate_utils = final.callPackage ../pkgs/syndicate_utils { };

  synit-network-utils = final.callPackage ../pkgs/synit-network-utils { };

  synit-pid1 = final.callPackage ../pkgs/synit-pid1 { };

  synit-service = final.callPackage ../pkgs/synit-service { };

  tclPackages = prev.tclPackages.overrideScope (import ../pkgs/tcl-modules);

  tcl9Packages =
    (prev.tclPackages.override {
      tcl = final.tcl-9_0;
      tk = final.tk-9_0;
    }).overrideScope
      (import ../pkgs/tcl-modules);

  # relevant software for systems without logind - potentially useful to finix
  pam_xdg = prev.callPackage ../pkgs/pam_xdg { };
}
