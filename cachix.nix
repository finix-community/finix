# nix-build ./cachix.nix | cachix push finix
let
  sources = import ./lon.nix;
  lib = import "${sources.nixpkgs}/lib";
  finix = import ./default.nix;

  configuration = { modules, ... }: {
    imports = with modules; [
      brightnessctl
      hyprland
      illum
      labwc
      mango
      niri
      pipewire
      regreet
      sway
      wireplumber
      xorg
      xinit
      flatpak
      gvfs
      polkit
    ];

    specialisation.libudev-zero = {
      services.mdevd.enable = true;
    };

    specialisation.libudev-garden = {
      services.gardendevd.enable = true;
    };

    specialisation.plymouth = {
      programs.plymouth.enable = true;
    };

    programs.brightnessctl.enable = true;
    programs.hyprland.enable = true;
    programs.labwc.enable = true;
    programs.mango.enable = true;
    programs.niri.enable = true;
    programs.pipewire.enable = true;
    programs.regreet.enable = true;
    programs.sway.enable = true;
    programs.wireplumber.enable = true;
    programs.xorg.enable = true;
    services.dbus.enable = true;
    services.flatpak.enable = true;
    services.gvfs.enable = true;
    services.illum.enable = true;
    services.polkit.enable = true;
  };

  out =
    lib.mapAttrs
      (
        _: v:
        let
          packageSet = config: {
            brightnessctl = config.programs.brightnessctl.package;
            cage = config.programs.regreet.compositor.package;
            finit = config.finit.package;
            flatpak = config.services.flatpak.package;
            hyprland = config.programs.hyprland.package;
            illum = config.services.illum.package;
            labwc = config.programs.labwc.package;
            mango = config.programs.mango.package;
            niri = config.programs.niri.package;
            pipewire = config.programs.pipewire.package;
            plymouth = config.programs.plymouth.package;
            polkit = config.services.polkit.package;
            sway = config.programs.sway.package;
            wireplumber = config.programs.wireplumber.package;
            xinit = config.programs.xinit.package;
            xorg = config.programs.xorg.package;
          };
        in
        {
          default = packageSet v.config;
        }
        // lib.mapAttrs (_: packageSet) v.config.specialisation
      )
      {
        x86_64-linux = finix.lib.finixSystem {
          inherit lib;

          modules = [
            configuration
            {
              nixpkgs.pkgs = import sources.nixpkgs {
                hostPlatform = "x86_64-linux";
              };
            }
          ];
        };

        # TODO: desktop musl support
        # x86_64-linux-musl = finix.lib.finixSystem {
        #   inherit lib;
        #
        #   modules = [
        #     configuration
        #     {
        #       nixpkgs.pkgs = import sources.nixpkgs {
        #         localSystem.config = "x86_64-unknown-linux-musl";
        #       };
        #     }
        #   ];
        # };
      };
in
lib.unique (lib.collect lib.isDerivation out)
