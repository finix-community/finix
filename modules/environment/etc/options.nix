{ pkgs, lib, ... }:
let
  etcOpts =
    {
      name,
      config,
      options,
      ...
    }:
    {
      options = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = ''
            Whether this /etc file should be generated.  This
            option allows specific /etc files to be disabled.
          '';
        };

        target = lib.mkOption {
          type = lib.types.str;
          description = ''
            Name of symlink (relative to
            {file}`/etc`).  Defaults to the attribute
            name.
          '';
        };

        text = lib.mkOption {
          type = with lib.types; nullOr lines;
          default = null;
          description = "Text of the file.";
        };

        source = lib.mkOption {
          type = lib.types.path;
          description = "Path of the source file.";
        };

        mode = lib.mkOption {
          type = lib.types.str;
          default = "symlink";
          example = "0600";
          description = ''
            If set to something else than `symlink`,
            the file is copied instead of symlinked, with the given
            file mode.
          '';
        };

        uid = lib.mkOption {
          type = lib.types.int;
          default = 0;
          description = ''
            UID of created file. Only takes effect when the file is
            copied (that is, the mode is not 'symlink').
          '';
        };

        gid = lib.mkOption {
          type = lib.types.int;
          default = 0;
          description = ''
            GID of created file. Only takes effect when the file is
            copied (that is, the mode is not 'symlink').
          '';
        };

        user = lib.mkOption {
          type = lib.types.str;
          default = "+${toString config.uid}";
          description = ''
            User name of created file.
            Only takes effect when the file is copied (that is, the mode is not 'symlink').
            Changing this option takes precedence over `uid`.
          '';
        };

        group = lib.mkOption {
          type = lib.types.str;
          default = "+${toString config.gid}";
          description = ''
            Group name of created file.
            Only takes effect when the file is copied (that is, the mode is not 'symlink').
            Changing this option takes precedence over `gid`.
          '';
        };

      };

      config = {
        target = lib.mkDefault name;
        source = lib.mkIf (config.text != null) (
          let
            name' = "etc-" + lib.replaceStrings [ "/" ] [ "-" ] name;
          in
          lib.mkDerivedConfig options.text (pkgs.writeText name')
        );
      };
    };
in
{
  options.environment.etc = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submoduleWith { modules = [ etcOpts ]; });
    default = { };
    example = lib.literalExpression ''
      { example-configuration-file =
          { source = "/nix/store/.../etc/dir/file.conf.example";
            mode = "0440";
          };
        "default/useradd".text = "GROUP=100 ...";
      }
    '';
    description = ''
      Set of files that have to be linked in {file}`/etc`.
    '';
  };
}
