{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.boot.initrd;

  modulesClosure = pkgs.makeModulesClosure {
    rootModules = config.boot.initrd.availableKernelModules ++ config.boot.initrd.kernelModules;
    kernel = config.system.modulesTree;
    firmware = config.hardware.firmware;
    allowMissing = false;
  };
in
{
  options.boot.initrd = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to enable the NixOS initial RAM disk (initrd). This may be
        needed to perform some initialisation tasks (like mounting
        network/encrypted file systems) before continuing the boot process.
      '';
    };

    compressor = lib.mkOption {
      default =
        if lib.versionAtLeast config.boot.kernelPackages.kernel.version "5.9" then "zstd" else "gzip";
      defaultText = lib.literalExpression "`zstd` if the kernel supports it (5.9+), `gzip` if not";
      type = with lib.types; either str (functionTo str);
      description = ''
        The compressor to use on the initrd image. May be any of:

        - The name of one of the predefined compressors, see {file}`pkgs/build-support/kernel/initrd-compressor-meta.nix` for the definitions.
        - A function which, given the nixpkgs package set, returns the path to a compressor tool, e.g. `pkgs: "''${pkgs.pigz}/bin/pigz"`
        - (not recommended, because it does not work when cross-compiling) the full path to a compressor tool, e.g. `"''${pkgs.pigz}/bin/pigz"`

        The given program should read data from stdin and write it to stdout compressed.
      '';
      example = "xz";
    };

    compressorArgs = lib.mkOption {
      default = null;
      type = with lib.types; nullOr (listOf str);
      description = "Arguments to pass to the compressor for the initrd image, or null to use the compressor's defaults.";
    };

    contents = lib.mkOption {
      type =
        with lib.types;
        listOf (submodule {
          options = {
            source = lib.mkOption {
              type = types.path;
            };
            target = lib.mkOption {
              type = with types; nullOr str;
              default = null;
            };
          };
        });
      description = ''
        Contents of the initrd.
      '';
    };

    fileSystemImportCommands = lib.mkOption {
      description = ''
        Lines of shell commands that are run after coldbooting
        the device-manager and before mounting file-systems.
      '';
      type = lib.types.lines;
      default = "";
      example = ''
        vgimport --all
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      description = "the initrd to use for your system... use a module to build one";
    };
  };

  config = {
    boot.initrd.supportedFilesystems =
      config.fileSystems
      |> lib.filterAttrs (_: fs: fs.neededForBoot)
      |> lib.mapAttrs' (_: v: lib.nameValuePair v.fsType { enable = true; });

    boot.initrd.package = pkgs.makeInitrdNG {
      name = "initrd-" + config.boot.kernelPackages.kernel.name or "kernel";
      inherit (cfg) compressor compressorArgs;
      contents = map (
        { source, target }@pair: if target != null then pair else { inherit source; }
      ) cfg.contents;
    };

    boot.initrd.contents = [
      {
        target = "/lib";
        source = "${modulesClosure}/lib";
      }
    ];
  };
}
