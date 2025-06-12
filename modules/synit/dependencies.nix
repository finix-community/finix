{ lib, config, pkgs, ... }:
let
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

  preserves = pkgs.formats.preserves {
    ignoreNulls = true;
    rawStrings = true;
  };

  writePreservesFile = preserves.generate;

  rootDependerKey = with config.system; [
    "milestone"
    "system-${config.networking.hostName}"
  ];

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
            key = keyOption // {
              default = rootDependerKey;
              defaultText = literalMD ''
                [ "milestone" "system-${config.networking.hostName}" ];
              '';
            };
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
        { key = [ "milestone" "devices" ]; }
        { key = [ "daemon" "dhcpcd" ]; state = "ready"; }
      ];
      type = types.attrsOf (
        types.submodule {
          options = {
            requires = mkOption {
              type = types.listOf dependeeType;
              description = "List of services required by this milestone";
            };
          };
        }
      );
    };
  };

  config = mkIf config.synit.enable {

    environment.etc =
      let
        # Make Preserves `<foo bar>` out of Nix `[ "foo" "bar" ]`.
        recordOfKey = key: tail key ++ [ { _record = head key; } ];

        # <depends-on <${recordOfKey key}> <service-state ${state}>>
        dependsOn = { key, dependee }: [
          (recordOfKey key) [
              (recordOfKey dependee.key)
              dependee.state
              { _record = "service-state"; }
            ]
            { _record = "depends-on"; }
          ];

        # Create a closure of dependencies for a given service.
        # This isn't strictly necessary because the syndicate-server
        # does this internally. By doing it in Nix we get a static
        # description of the dependency graph which can be analysed
        # before booting.
        serviceClosure =
          root:
          map (getAttr "node") (
            # Encapsulate a relation with a unique key
            # for insertion into the closure set.
            let idx = node: {
              inherit node;
              key = node.key ++ node.dependee.key ++ [ node.dependee.state ];
            }; in
            # The evaluator provides builtin.genericClosure
            # for these sorts of tasks.
            genericClosure {
              startSet = [ (idx root) ];
              # Collect all relations for each
              # node inserted in the set.
              operator = { node, ... }:
                config.synit.depends
                |> filter ({ key, ... }: key == node.dependee.key)
                |> map idx;
            });

        # Generate a file that asserts the dependency graph
        # for a given service.
        writeRequires =
          topReq:
          let
            fileName = "require-${concatStringsSep "-" (flatten topReq.dependee.key)}.pr";
          in
          {
            "syndicate/services/${fileName}".source = writePreservesFile fileName (
              map dependsOn (serviceClosure topReq)
            );
          };

        # Collect the services that system milestone depends on.
        systemRequires = filter ({ key, ... }: key == rootDependerKey) config.synit.depends;
      in
      # Each immediate dependency of the system milestone
      # has a file that asserts its dependency graph.
      # The intention is that if this files is removed
      # at runtime then its exclusive dependencies are
      # retracted but the graphs of other services are
      # unaffected.
      mkMerge (
        (map writeRequires systemRequires)
        ++ [ {
          # The system milestone is a tautological dependency.
          "syndicate/services/require-nixos.pr".source = writePreservesFile "require-nixos.pr" [
            [
              (recordOfKey rootDependerKey)
              { _record = "require-service"; }
            ]
          ];
        }]
      );

    # Declare the initial milestones.
    # If no further relations are declared for
    # these then they will be immediately
    # asserted as ready.
    synit.milestones.system.requires = map
      (name: { key = [ "milestone" name ]; })
      [ "network" "login" ];

    # Accumulate all milestones into the top-level
    # collection of relations.
    synit.depends = foldl' (
      depends:
      { name, value }:
      let milestone =
        if name == "system"
        then rootDependerKey
        else [ "milestone" name ];
      in
      depends ++ map
        (dependee: { key = milestone; inherit dependee; })
        value.requires
    ) [ ] (attrsToList config.synit.milestones);

  };

}
