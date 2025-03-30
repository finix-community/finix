{
  description = "A simple desktop running the niri scrollable-tiling wayland compositor";

  inputs = {
    finix.url = "github:aanderse/finix";
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, finix, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
    let
      inherit (nixpkgs) lib;

      pkgs = import nixpkgs {
        inherit system;

        config.allowUnfree = true;
        overlays = [
          finix.overlays.default

          # work in progress overlay to build software without systemd, not currently usable
          # finix.overlays.without-systemd
        ];
      };

      os = lib.evalModules {
        specialArgs = {
          inherit pkgs;
        };

        modules = [
          ./configuration.nix
        ] ++ lib.attrValues finix.nixosModules;
      };
    in
    {
      apps = {
        grub = flake-utils.lib.mkApp {
          drv = pkgs.writeShellApplication {
            name = "update-grub-entries.sh";
            text = ''
              echo "generating grub entries..."

              {
                storepath=$(realpath /nix/var/nix/profiles/system)

                echo
                echo "menuentry \"finix - default\" {"
                echo "  linux $storepath/kernel root=/dev/sda4 ro init=$storepath/init loglevel=1"
                echo "  initrd $storepath/initrd"
                echo "}"

                echo
                echo "menuentry \"finix - debug\" {"
                echo "  linux $storepath/kernel root=/dev/sda4 ro init=$storepath/init -- finit.debug=true"
                echo "  initrd $storepath/initrd"
                echo "}"

                echo
                echo "submenu \"finix - all configurations\" {"

                find /nix/var/nix/profiles/ -name 'system-*-link' | sort -Vr | while read -r profile; do
                  storepath=$(realpath "$profile")
                  dt=$(date -d @"$(stat --format %Y "$profile")" +'%Y%m%d @ %H%M%S')
                  gen=$(basename "$profile" | awk -F'-' '{ print $2 }')

                  echo
                  echo "  menuentry \"finix generation $gen ${nixpkgs.shortRev} - $dt\" {"
                  echo "    linux $storepath/kernel root=/dev/sda4 ro init=$storepath/init"
                  echo "    initrd $storepath/initrd"
                  echo "  }"
                done

                echo "}"
              } > /boot/grub/custom.cfg
            '';
          };
        };
      };

      packages = {
        system = pkgs.stdenvNoCC.mkDerivation {
          name = "finix-system";
          preferLocalBuild = true;
          allowSubstitutes = false;
          buildCommand = ''
            mkdir -p $out

            echo ${self.dirtyShortRev or self.shortRev} > $out/nixos-version

            cp ${os.config.system.activation.out} $out/activate
            cp ${os.config.boot.init.script} $out/init

            ${pkgs.coreutils}/bin/ln -s ${os.config.environment.path} $out/sw

            substituteInPlace $out/activate --subst-var-by systemConfig $out
            substituteInPlace $out/init --subst-var-by systemConfig $out
          '' + lib.optionalString os.config.boot.kernel.enable ''
            ${pkgs.coreutils}/bin/ln -s ${os.config.boot.kernelPackages.kernel}/bzImage $out/kernel
            ${pkgs.coreutils}/bin/ln -s ${os.config.system.modulesTree} $out/kernel-modules
            ${pkgs.coreutils}/bin/ln -s ${os.config.hardware.firmware}/lib/firmware $out/firmware
          '' + lib.optionalString os.config.boot.initrd.enable ''
            ${pkgs.coreutils}/bin/ln -s ${os.config.boot.initrd.package}/initrd $out/initrd
          '';
        };

        default = self.packages.${system}.system;
      };
    });

  nixConfig = {
    extra-experimental-features = [ "flakes" "nix-command" "pipe-operators" ];
  };
}
