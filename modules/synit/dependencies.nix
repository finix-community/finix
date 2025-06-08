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
                [ "milestone" "nixos-''${config.name}-''${config.nixos.label}" ];
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
        recordOfKey = key: tail key ++ [ { _record = head key; } ];

        dependsOn = { key, dependee }: [
          (recordOfKey key) [
              (recordOfKey dependee.key)
              dependee.state
              { _record = "service-state"; }
            ]
            { _record = "depends-on"; }
          ];

        serviceClosure =
          root:
          map (getAttr "node") (
            let idx = node: {
              inherit node;
              key = node.key ++ node.dependee.key ++ [ node.dependee.state ];
            }; in
            genericClosure {
              startSet = [ (idx root) ];
              operator = { node, ... }:
                config.synit.depends
                |> filter ({ key, ... }: key == node.dependee.key)
                |> map idx;
            });

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

        systemRequires = filter ({ key, ... }: key == rootDependerKey) config.synit.depends;
      in
      mkMerge (
        (map writeRequires systemRequires)
        ++ [
          {
            "syndicate/services/require-nixos.pr".source = writePreservesFile "require-nixos.pr" [
              [
                (recordOfKey rootDependerKey)
                { _record = "require-service"; }
              ]
            ];
          }
        ]
      );

    # Create the initial system requirements.
    synit.milestones.system.requires = map
      (name: { key = [ "milestone" name ]; })
      [ "network" "login" ];

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
