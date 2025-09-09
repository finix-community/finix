{...}@args:
let
  self = {
    sources = import ./npins;

    modules = import ./modules;

    overlays = {
      # software required for finix to operate
      default = import ./pkgs/overlay.nix;

      # apply modular services to packages for convenience
      modularServices = import ./overlays/modular-services.nix;

      # packages only needed by Synit
      sampkgs = final: prev: {
        # use an indirection to lazy load this overlay
        sampkgs = builtins.trace
          "loading sampkgs overlay"
          ((import self.sources.sampkgs).overlay final prev).sampkgs;
      };

      # work in progress overlay to build software in nixpkgs without systemd
      withoutSystemd = import ./overlays/without-systemd.nix;

      # can be used to relieve packages from requiring udev at runtime
      withoutUdev = import ./overlays/without-udev.nix;
    };

    pkgs = import self.sources.nixpkgs {
      config = { };
      overlays = with self.overlays; [
          default
          modularServices
          sampkgs
        ];
    };

    inherit (self.pkgs) lib;

    tests =
      let
        testArgs.testenv =
          import ./tests/testenv/tcl { inherit (self) lib pkgs; };
      in
      with builtins;
      readDir ./tests
      |> attrNames
      |> filter (x: !(elem x [ "default.nix" "testenv" ]))
      |> map (p: {
        name = self.lib.removeSuffix ".nix" p;
        value = import ./tests/${p} testArgs;
      })
      |> listToAttrs;
  } // args;
in self
