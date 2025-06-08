{
  lib,
  rustPlatform,
  fetchFromGitea,
}:

rustPlatform.buildRustPackage rec {
  pname = "synit-pid1";
  version = "0.0.5";

  src = fetchFromGitea {
    domain = "git.syndicate-lang.org";
    owner = "ehmry";
    repo = "synit-pid1";
    rev = "4c97408f5867cff77161b48aceff8b06e087aa7d";
    hash = "sha256-Rj4cST2U9xhV0syMAR+j+rxWqqPLIDQeRvXsp9WaImA=";
  };

  cargoHash = "sha256-1rvQxvVqvZ8iDq4i52E38LXCoIvNF+o6NhqEmsn+dlQ=";
  useFetchCargoVendor = true;

  RUSTC_BOOTSTRAP = true;

  meta = {
    description = "Synit PID1 program";
    homepage = "https://synit.org/";
    license = lib.licenses.asl20;
    mainProgram = "synit-pid1";
    maintainers = with lib.maintainers; [ ehmry ];
  };
}
