{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.dinit;

  settingsFormat = import ./format.nix { inherit pkgs lib; };
  dinitSwitchScript = pkgs.writeText "dinit-switch.py" (builtins.readFile ./dinit-switch.py);

  targetData = import ./target-names.nix { inherit lib; };
  targetNames = targetData.names;
  targetDefinitions = targetData.definitions;
  rootTarget = targetData.root;
  rootDirectory = targetDefinitions.${rootTarget}."depends-on.d";

  targetDirectories = lib.unique (
    lib.concatMap (
      definition:
      lib.optional (definition ? "depends-on.d") definition."depends-on.d"
      ++ lib.optional (definition ? "waits-for.d") definition."waits-for.d"
    ) (lib.attrValues targetDefinitions)
  );
  targetServices = lib.attrNames targetDefinitions;

  enabledServices = lib.filterAttrs (_: service: service.enable) cfg.services;
  reservedNames = targetServices ++ targetDirectories ++ [ "user" ];
  invalidServiceNames = lib.filter (
    name: name == "" || name == "." || name == ".." || lib.hasInfix "/" name
  ) (lib.attrNames cfg.services);
  invalidUserServiceNames = lib.filter (
    name: name == "" || name == "." || name == ".." || lib.hasInfix "/" name
  ) (lib.attrNames cfg.user.services);
  conflictingServiceNames = lib.filter (name: lib.elem name reservedNames) (
    lib.attrNames cfg.services
  );

  dinitManifest = pkgs.writeText "dinit-manifest.json" (
    builtins.toJSON ({
      services = lib.mapAttrs (_: service: {
        startOnSwitch = service.targets != [ ];
      }) enabledServices;
      inherit targetDirectories targetServices;
    })
  );

  serviceFileAttrs = [
    "enable"
    "environment"
    "path"
    "targets"
  ];

  serviceTree = lib.mapAttrs' (name: service: {
    name = "dinit.d/${name}";
    value.source = settingsFormat.generate name (builtins.removeAttrs service serviceFileAttrs);
  }) enabledServices;

  userTree = lib.mapAttrs' (name: service: {
    name = "dinit.d/user/${name}";
    value.source = settingsFormat.generate name (
      builtins.removeAttrs service [
        "enable"
        "environment"
        "path"
      ]
    );
  }) (lib.filterAttrs (_: service: service.enable) cfg.user.services);

  targetTree = lib.mapAttrs' (name: definition: {
    name = "dinit.d/${name}";
    value.source = settingsFormat.generate name definition;
  }) targetDefinitions;

  keepTree = lib.listToAttrs (
    map (directory: {
      name = "dinit.d/${directory}/.keep";
      value.text = "";
    }) targetDirectories
  );

  bootLinks = map (name: "${name}.target") targetNames;

  targetLinks = lib.flatten (
    lib.mapAttrsToList (
      name: service:
      map (target: {
        inherit name target;
      }) service.targets
    ) enabledServices
  );

  mkLinks =
    directory: names:
    lib.concatMapStrings (
      name:
      "ln -sfn ../${lib.escapeShellArg name} ${lib.escapeShellArg "/etc/dinit.d/${directory}/${name}"}\n"
    ) names;

  mkTargetLinks = lib.concatMapStrings (
    link:
    "ln -sfn ../${lib.escapeShellArg link.name} ${lib.escapeShellArg "/etc/dinit.d/${link.target}.d/${link.name}"}\n"
  ) targetLinks;
in
{
  config = lib.mkMerge [
    (lib.mkIf (config.system.init == "dinit") {
      assertions = [
        {
          assertion = invalidServiceNames == [ ];
          message = ''
            dinit.services contains invalid service names: ${lib.concatStringsSep ", " invalidServiceNames}.
            Service names must not contain `/` or be `.`/`..`.
          '';
        }
        {
          assertion = conflictingServiceNames == [ ];
          message = ''
            dinit.services contains reserved service names: ${lib.concatStringsSep ", " conflictingServiceNames}.
            Reserved names include the Dinit targets and target directories.
          '';
        }
      ];

      environment.systemPackages = [ cfg.package ];

      environment.etc = serviceTree // targetTree // keepTree;

      dinit.services.mount-fstab = {
        type = "scripted";
        command = "${pkgs.util-linux}/bin/mount -a";
        targets = [ "filesystem" ];
      };

      system.activation.scripts.dinit-target-links = {
        deps = [ "etc" ];
        text =
          lib.concatMapStrings (directory: ''
            find ${lib.escapeShellArg "/etc/dinit.d/${directory}"} -mindepth 1 -maxdepth 1 -type l -delete
          '') targetDirectories
          + mkLinks rootDirectory bootLinks
          + mkTargetLinks;
      };

      system.activation.scripts.dinit-switch = {
        deps = [
          "etc"
          "dinit-target-links"
        ];
        text = ''
          ${pkgs.python3}/bin/python3 ${dinitSwitchScript} \
            --dinitctl ${cfg.package}/bin/dinitctl \
            --manifest ${dinitManifest}
        '';
      };
    })

    (lib.mkIf cfg.user.enable {
      assertions = [
        {
          assertion = invalidUserServiceNames == [ ];
          message = ''
            dinit.user.services contains invalid service names: ${lib.concatStringsSep ", " invalidUserServiceNames}.
            Service names must not contain `/` or be `.`/`..`.
          '';
        }
      ];
      environment.systemPackages = lib.mkIf (cfg.user.services != { }) [ cfg.package ];
      environment.etc = userTree;
    })
  ];
}
