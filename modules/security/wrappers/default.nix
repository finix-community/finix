# TODO: this belongs in core api
{ config, lib, pkgs, ... }:
let
  fileModeType =
    let
      # taken from the chmod(1) man page
      symbolic = "[ugoa]*([-+=]([rwxXst]*|[ugo]))+|[-+=][0-7]+";
      numeric = "[-+=]?[0-7]{0,4}";
      mode = "((${symbolic})(,${symbolic})*)|(${numeric})";
    in
     lib.types.strMatching mode
     // { description = "file mode string"; };

  wrapperType = lib.types.submodule ({ name, ... }: {
    options.source = lib.mkOption
      { type = lib.types.path;
        description = "The absolute path to the program to be wrapped.";
      };
    options.program = lib.mkOption
      { type = with lib.types; nullOr str;
        default = name;
        description = ''
          The name of the wrapper program. Defaults to the attribute name.
        '';
      };
    options.owner = lib.mkOption
      { type = lib.types.str;
        description = "The owner of the wrapper program.";
      };
    options.group = lib.mkOption
      { type = lib.types.str;
        description = "The group of the wrapper program.";
      };
    options.permissions = lib.mkOption
      { type = fileModeType;
        default  = "u+rx,g+x,o+x";
        example = "a+rx";
        description = ''
          The permissions of the wrapper program. The format is that of a
          symbolic or numeric file mode understood by {command}`chmod`.
        '';
      };
    options.capabilities = lib.mkOption # TODO: this is a linux specific option, wouldn't apply to bsd
      { type = lib.types.commas;
        default = "";
        description = ''
          A comma-separated list of capability clauses to be given to the
          wrapper program. The format for capability clauses is described in the
          “TEXTUAL REPRESENTATION” section of the {manpage}`cap_from_text(3)`
          manual page. For a list of capabilities supported by the system, check
          the {manpage}`capabilities(7)` manual page.

          ::: {.note}
          `cap_setpcap`, which is required for the wrapper
          program to be able to raise caps into the Ambient set is NOT raised
          to the Ambient set so that the real program cannot modify its own
          capabilities!! This may be too restrictive for cases in which the
          real program needs cap_setpcap but it at least leans on the side
          security paranoid vs. too relaxed.
          :::
        '';
      };
    options.setuid = lib.mkOption
      { type = lib.types.bool;
        default = false;
        description = "Whether to add the setuid bit the wrapper program.";
      };
    options.setgid = lib.mkOption
      { type = lib.types.bool;
        default = false;
        description = "Whether to add the setgid bit the wrapper program.";
      };
  });
in
{
  imports = [
    ./s6-sudo.nix
    ./setuid.nix
  ];

  options = {
    security.wrappers = lib.mkOption {
      type = lib.types.attrsOf wrapperType;
      default = {};
      description = ''
        This option effectively allows adding setuid/setgid bits, capabilities,
        changing file ownership and permissions of a program without directly
        modifying it. This works by creating a wrapper program under the
        {option}`security.wrapperDir` directory, which is then added to
        the shell `PATH`.
      '';
    };

    security.wrapperDirSize = lib.mkOption {
      default = "50%";
      example = "10G";
      type = lib.types.str;
      description = ''
        Size limit for the /run/wrappers tmpfs. Look at mount(8), tmpfs size option,
        for the accepted syntax. WARNING: don't set to less than 64MB.
      '';
    };

    security.wrapperDir = lib.mkOption {
      type        = lib.types.path;
      internal    = true;
      description = ''
        This option defines the path to the wrapper programs. It
        should not be overridden.
      '';
    };

    security.wrapperMethod = lib.mkOption {
      description = ''
        This option defines how security wrappers are implemented.
      '';
      type = lib.types.enum [ "setuid" "s6-sudo" ];
      default = "setuid";
    };

  };
}
