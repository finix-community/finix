{
  lib,
  stdenv,
  buildNimSbom,
  fetchFromGitea,
  nix,
  openssl,
  pkg-config,
}:

buildNimSbom (finalAttrs: {
  version = "0.20250830";

  src = fetchFromGitea {
    domain = "git.syndicate-lang.org";
    owner = "ehmry";
    repo = "nix_actor";
    rev = "1621aaa7601224febac7a504c662bb8bad4dd554";
    hash = "sha256-y1yc94nYOEd0xuqKo+mDvbVjr3B/lmK8eVvfe+QUNCg=";
  };

  nativeBuildInputs = [ pkg-config ];

  buildInputs = [
    nix
    openssl
  ];

  env.NIX_CFLAGS_COMPILE = lib.optionalString stdenv.cc.isGNU "-Wno-error=incompatible-pointer-types";

  meta = {
    mainProgram = "nix-actor";
  };

}) ./sbom.json
