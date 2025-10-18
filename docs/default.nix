# https://github.com/snugnug/hjem-rum/blob/main/docs/package.nix
let
  inherit (pkgs) lib;

  sources = import ../lon.nix;
  ndg = pkgs.callPackage (toString sources.ndg + "/flake/packages/ndg/package.nix") { };
  pkgs = import sources.nixpkgs {
    overlays = [
      (import ../overlays/default.nix)
    ];
  };

  modulesPath = toString sources.nixpkgs + "/nixos/modules";

  eval = lib.evalModules {
    specialArgs = {
      inherit modulesPath;
    };
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

  # needed until we stop importing nixos modules
  nixosOptionsDoc =
    attrs:
    (import ./make-options-doc.nix) (
      {
        pkgs = pkgs.__splicedPackages;
        inherit lib;
      }
      // attrs
    );

  doc = nixosOptionsDoc {
    options = eval.options;
    warningsAreErrors = false;

    transformOptions = opt:
      opt
      // {
        declarations =
          map (
            decl:
              if lib.hasPrefix (toString ../modules) (toString decl)
              then
                decl
                  |> toString
                  |> lib.removePrefix (toString ../modules)
                  |> (x: {
                    url = "https://github.com/finix-community/finix/blob/main/modules${x}";
                    name = "<finix/modules${x}>";
                  })
              else if lib.hasPrefix modulesPath (toString decl)
              then {
                url = "https://github.com/NixOS/nixpkgs/blob/master/nixos/modules${lib.removePrefix modulesPath (toString decl)}";
                name = "<nixpkgs/nixos/modules${lib.removePrefix modulesPath (toString decl)}>";
              }
              else decl
          )
          opt.declarations;
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
