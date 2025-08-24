{
  lib,
  rustPlatform,
  fetchFromGitea,
  pkg-config,
  openssl,
  versionCheckHook,
}:

rustPlatform.buildRustPackage rec {
  pname = "syndicate-server";
  version = "0.51.0-rc.1-8-g0b66d4c";
  src = fetchFromGitea {
    domain = "git.syndicate-lang.org";
    owner = "ehmry";
    repo = "syndicate-rs";
    rev = "0b66d4c8b9a0189aca681014196e69a80cd313ac";
    hash = "sha256-d2WdNeyK2pNras3ijwREr18gRlpnfi27EM3u/nEmH5g=";
  };
  cargoHash = "sha256-buUTej9fR0DdQKVKgQK/3kpkcw/C//CqZS37C5cClH0=";

  nativeBuildInputs = [
    pkg-config
    versionCheckHook
  ];

  buildInputs = [ openssl ];

  RUSTC_BOOTSTRAP = 1;

  # Renable the check when back on a release.
  doInstallCheck = false;

  meta = {
    description = "Syndicate broker server";
    homepage = "https://synit.org/";
    license = lib.licenses.asl20;
    mainProgram = "syndicate-server";
    maintainers = with lib.maintainers; [ ehmry ];
    platforms = lib.platforms.linux;
  };
}
