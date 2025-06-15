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
  version = "0.51.0-rc.1";
  src = fetchFromGitea {
    domain = "git.syndicate-lang.org";
    owner = "syndicate-lang";
    repo = "syndicate-rs";
    rev = "${pname}-v${version}";
    hash = "sha256-D8VYdo86ukPQXNnkZYXoDmBJuUXa4OEtHyDgD9otGlU=";
  };
  useFetchCargoVendor = true;
  cargoHash = "sha256-7RIioEOKa4pmJHaxugs8CJXu+aL1cRpdBfLm+tb2hwQ=";
  nativeBuildInputs = [
    pkg-config
    versionCheckHook
  ];
  buildInputs = [ openssl ];

  RUSTC_BOOTSTRAP = 1;

  doCheck = false;
  doInstallCheck = true;

  meta = {
    description = "Syndicate broker server";
    homepage = "https://synit.org/";
    license = lib.licenses.asl20;
    mainProgram = "syndicate-server";
    maintainers = with lib.maintainers; [ ehmry ];
    platforms = lib.platforms.linux;
  };
}
