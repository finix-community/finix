# https://github.com/snugnug/hjem-rum/blob/main/docs/package.nix
let
  inherit (pkgs) lib;

  sources = import ../lon.nix;
  ndg = pkgs.callPackage (toString sources.ndg + "/flake/packages/ndg/package.nix") { };
  pkgs = import sources.nixpkgs { };

  eval = lib.evalModules {
    modules = [
      {
        imports = builtins.attrValues (import ../modules);
        nixpkgs.pkgs = pkgs;
      }
      {
        options = {
          _module.args = lib.mkOption {
            internal = true;
          };
        };
      }
    ];
  };

  doc = pkgs.nixosOptionsDoc {
    options = eval.options;
    warningsAreErrors = false;

    transformOptions =
      opt:
      opt
      // {
        declarations = map (
          decl:
          decl
          |> toString
          |> lib.removePrefix (toString ../modules)
          |> (x: {
            url = "https://github.com/finix-community/finix/blob/main/modules${x}";
            name = "<finix/modules${x}>";
          })
        ) opt.declarations;
      };
  };
in
pkgs.runCommandLocal "finix-options-doc" { nativeBuildInputs = [ ndg ]; } ''
  mkdir -p $out

  ndg html \
    --jobs $NIX_BUILD_CORES \
    --title finix \
    --module-options ${doc.optionsJSON}/share/doc/nixos/options.json \
    --manpage-urls ${./manpage-urls.json} \
    --options-depth 1 \
    --generate-search \
    --output-dir "$out"
''
