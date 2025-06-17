{
  lib,
  buildNimSbom,
  fetchFromGitea,
  libxml2,
  libxslt,
  openssl,
  libpq,
  sqlite,
}:

buildNimSbom (finalAttrs: {
  pname = "syndicate_utils";

  src = fetchFromGitea {
    domain = "git.syndicate-lang.org";
    owner = "ehmry";
    repo = "syndicate_utils";
    rev = finalAttrs.version;
    hash = "sha256-8hozL+HKJOY7EJ8mr26YL+B0jYfRG5sZhFFkLJXT/88=";
  };

  buildInputs = [
    libpq
    sqlite
    libxml2
    libxslt
    openssl
  ];

  meta = {
    description = "Syndicate utils";
    homepage = "https://git.syndicate-lang.org/ehmry/syndicate_utils";
    license = lib.licenses.unlicense;
    maintainers = with lib.maintainers; [ ehmry ];
  };
}) ./sbom.json
