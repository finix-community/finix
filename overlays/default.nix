final: prev: {
  __toString = _: "${prev.__toString or (_: "nixpkgs") prev}:Finix";

  lib = import ../pkgs/lib |> prev.lib.extend;

  finix-rebuild = final.callPackage ../pkgs/finix-rebuild { };

  # relevant software for systems without logind - potentially useful to finix
  pam_xdg = prev.callPackage ../pkgs/pam_xdg { };
}
