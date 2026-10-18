# https://github.com/snugnug/hjem-rum/blob/main/docs/package.nix
let
  inherit (pkgs) lib;

  sources = import ../lon.nix;
  pkgs = import sources.nixpkgs { };
  modules = import ../modules;

  eval = lib.evalModules {
    class = "nixos";
    specialArgs = { inherit modules; };
    modules = [
      {
        imports = builtins.attrValues modules;
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
    inherit (eval) options;
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

  ndgConfig = pkgs.replaceVars ./ndg.toml { logo = "${../assets/finix-logo.svg}"; };
in
pkgs.runCommandLocal "finix-documentation" { nativeBuildInputs = [ pkgs.ndg ]; } ''
  mkdir -p $out

  ndg --config-file ${ndgConfig} \
    html \
    --jobs $NIX_BUILD_CORES \
    --title finix \
    --module-options ${doc.optionsJSON}/share/doc/nixos/options.json \
    --manpage-urls ${./manpage-urls.json} \
    --input-dir ${./manual} \
    --template-dir ${./templates} \
    --output-dir "$out"
''
