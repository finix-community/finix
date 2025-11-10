{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.synit;

  inherit (lib)
    attrsToList
    concatStringsSep
    filter
    flatten
    foldl'
    genericClosure
    getAttr
    head
    literalMD
    mkIf
    mkMerge
    mkOption
    tail
    types
    ;

  toPreserves = lib.generators.toPreserves { rawStrings = true; };

  keyOption = mkOption {
    type = types.listOf types.str;
    description = ''
      Label of a service.
      The head of the list is the record label and the tail is the fields.
    '';
  };

  # TODO: This format of relations makes for
  # a lot of brackets and is awkward to read.
  dependeeType = types.submodule {
    options = {
      key = keyOption;
      state = mkOption {
        type = types.str;
        default = "up";
        description = "Required service state.";
      };
    };
  };

  toRecord = fields: with builtins; tail fields ++ [ { _record = head fields; } ];

  dependsOn =
    { key, dependee }:
    [
      (toRecord key)
      [
        (toRecord dependee.key)
        dependee.state
        { _record = "service-state"; }
      ]
      { _record = "depends-on"; }
    ];

in
{
  options.synit = {
    depends = mkOption {
      description = ''
        List of edges in the service dependency graph.
        This list is populated from other options but
        dependencies can also be explicitly specified here.
      '';
      type = types.listOf (
        types.submodule {
          options = {
            key = keyOption;
            dependee = mkOption {
              type = dependeeType;
              description = ''
                Service that will be started if its dependers are required.
              '';
            };
          };
        }
      );
    };

    milestones = mkOption {
      description = ''
        Attribute set of service milestones and their dependees.
        A milestone will not be required unless it has been added
        to {option}.`synit.milestones.system.requires`.
      '';
      example.network.requires = [
        {
          key = [
            "milestone"
            "devices"
          ];
        }
        {
          key = [
            "daemon"
            "dhcpcd"
          ];
          state = "ready";
        }
      ];
      type = types.attrsOf (
        types.submodule {
          options = {
            requires = mkOption {
              type = types.listOf dependeeType;
              description = "List of services required by this milestone";
              default = [ ];
            };
            provides = mkOption {
              type = with types; listOf (listOf str);
              default = [ ];
              description = ''
                Reverse requires of this milestone.
                It is a list of service keys.
              '';
            };
          };
        }
      );
    };
  };

  config = mkIf cfg.enable {

    assertions =
      let
        missingDeamons =
          with builtins;
          filter (
            { dependee, ... }:
            let
              hasName = hasAttr (elemAt dependee.key 1);
            in
            !((head dependee.key) != "daemon" || ((hasName cfg.daemons) || (hasName cfg.core.daemons)))
          ) cfg.depends;
      in
      [
        {
          assertion = missingDeamons == [ ];
          message = "Some daemons are required but not defined: ${
            missingDeamons |> map dependsOn |> toPreserves
          }";
        }
      ];

    # Declare the initial milestones.
    # If no further relations are declared for
    # these then they will be immediately
    # asserted as ready.
    synit.milestones = {
      login = { };
      network = { };
    };

    # Accumulate all milestones into the top-level
    # collection of relations.
    synit.depends = foldl' (
      depends:
      { name, value }:
      let
        key = [
          "milestone"
          name
        ];
      in
      depends
      ++ map (other: {
        key = other;
        dependee.key = key;
      }) value.provides
      ++ map (dependee: { inherit key dependee; }) value.requires
    ) [ ] (attrsToList cfg.milestones);

    synit.plan.config.dependencies = map dependsOn cfg.depends;

  };

}
