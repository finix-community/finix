{ config, pkgs, lib, ... }:
let
  cfg = config.services.nix-daemon;

  configType =
    let
      confAtom = with lib.types;
        nullOr (oneOf [
          bool
          int
          float
          str
          path
          package
        ])
        // {
          description = "Nix config atom (null, bool, int, float, str, path or package)";
        };
    in
    lib.types.attrsOf (lib.types.either confAtom (lib.types.listOf confAtom));

  configFile =
    let
      mkValueString =
        v:
        if v == null then
          ""
        else if lib.isInt v then
          toString v
        else if lib.isBool v then
          lib.boolToString v
        else if lib.isFloat v then
          lib.floatToString v
        else if lib.isList v then
          toString v
        else if lib.isDerivation v then
          toString v
        else if builtins.isPath v then
          toString v
        else if lib.isString v then
          v
        else if lib.strings.isConvertibleWithToString v then
          toString v
        else
          abort "The nix conf value: ${lib.toPretty { } v} can not be encoded";

      mkKeyValue = k: v: "${lib.escape [ "=" ] k} = ${mkValueString v}";

      mkKeyValuePairs = attrs: lib.concatStringsSep "\n" (lib.mapAttrsToList mkKeyValue attrs);

      isExtra = key: lib.hasPrefix "extra-" key;

    in
      # workaround for https://github.com/NixOS/nix/issues/9487
      # extra-* settings must come after their non-extra counterpart
      pkgs.writeText "nix.conf" ''
        ${mkKeyValuePairs (lib.filterAttrs (key: value: !(isExtra key)) cfg.settings)}
        ${mkKeyValuePairs (lib.filterAttrs (key: value: isExtra key) cfg.settings)}
      '';
in
{
  options.services.nix-daemon = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [nix](${pkgs.nix.meta.homepage}) as a system service.

        ::: {.warning}
        Disabling `nix` makes the system hard to modify and the Nix programs and configuration will not be made available by NixOS itself.
        :::
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.nix;
      defaultText = lib.literalExpression "pkgs.nix";
      description = ''
        The package to use for `nix`.
      '';
    };

    nrBuildUsers = lib.mkOption {
      type = lib.types.int;
      default = 8;
      description = ''
        Number of `nixbld` user accounts created to
        perform secure concurrent builds.  If you receive an error
        message saying that "all build users are currently in use",
        you should increase this value.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = configType;

        options = {
          max-jobs = lib.mkOption {
            type = with lib.types; either int (enum [ "auto" ]);
            default = "auto";
            example = 64;
            description = ''
              This option defines the maximum number of jobs that Nix will try to
              build in parallel. The default is auto, which means it will use all
              available logical cores. It is recommend to set it to the total
              number of logical cores in your system (e.g., 16 for two CPUs with 4
              cores each and hyper-threading).
            '';
          };

          auto-optimise-store = lib.mkOption {
            type = lib.types.bool;
            default = false;
            example = true;
            description = ''
              If set to true, Nix automatically detects files in the store that have
              identical contents, and replaces them with hard links to a single copy.
              This saves disk space. If set to false (the default), you can still run
              nix-store --optimise to get rid of duplicate files.
            '';
          };

          cores = lib.mkOption {
            type = lib.types.int;
            default = 0;
            example = 64;
            description = ''
              This option defines the maximum number of concurrent tasks during
              one build. It affects, e.g., -j option for make.
              The special value 0 means that the builder should use all
              available CPU cores in the system. Some builds may become
              non-deterministic with this option; use with care! Packages will
              only be affected if enableParallelBuilding is set for them.
            '';
          };

          sandbox = lib.mkOption {
            type = with lib.types; either bool (enum [ "relaxed" ]);
            default = true;
            description = ''
              If set, Nix will perform builds in a sandboxed environment that it
              will set up automatically for each build. This prevents impurities
              in builds by disallowing access to dependencies outside of the Nix
              store by using network and mount namespaces in a chroot environment.

              This is enabled by default even though it has a possible performance
              impact due to the initial setup time of a sandbox for each build. It
              doesn't affect derivation hashes, so changing this option will not
              trigger a rebuild of packages.

              When set to "relaxed", this option permits derivations that set
              `__noChroot = true;` to run outside of the sandboxed environment.
              Exercise caution when using this mode of operation! It is intended to
              be a quick hack when building with packages that are not easily setup
              to be built reproducibly.
            '';
          };

          substituters = lib.mkOption {
            type = with lib.types; listOf str;
            description = ''
              List of binary cache URLs used to obtain pre-built binaries
              of Nix packages.

              By default https://cache.nixos.org/ is added.
            '';
          };

          trusted-substituters = lib.mkOption {
            type = with lib.types; listOf str;
            default = [ ];
            example = [ "https://hydra.nixos.org/" ];
            description = ''
              List of binary cache URLs that non-root users can use (in
              addition to those specified using
              {option}`nix.settings.substituters`) by passing
              `--option binary-caches` to Nix commands.
            '';
          };

          require-sigs = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              If enabled (the default), Nix will only download binaries from binary caches if
              they are cryptographically signed with any of the keys listed in
              {option}`nix.settings.trusted-public-keys`. If disabled, signatures are neither
              required nor checked, so it's strongly recommended that you use only
              trustworthy caches and https to prevent man-in-the-middle attacks.
            '';
          };

          trusted-public-keys = lib.mkOption {
            type = with lib.types; listOf str;
            example = [ "hydra.nixos.org-1:CNHJZBh9K4tP3EKF6FkkgeVYsS3ohTl+oS0Qa8bezVs=" ];
            description = ''
              List of public keys used to sign binary caches. If
              {option}`nix.settings.trusted-public-keys` is enabled,
              then Nix will use a binary from a binary cache if and only
              if it is signed by *any* of the keys
              listed here. By default, only the key for
              `cache.nixos.org` is included.
            '';
          };

          trusted-users = lib.mkOption {
            type = with lib.types; listOf str;
            example = [
              "root"
              "alice"
              "@wheel"
            ];
            description = ''
              A list of names of users that have additional rights when
              connecting to the Nix daemon, such as the ability to specify
              additional binary caches, or to import unsigned NARs. You
              can also specify groups by prefixing them with
              `@`; for instance,
              `@wheel` means all users in the wheel
              group.
            '';
          };

          system-features = lib.mkOption {
            type = with lib.types; listOf str;
            description = ''
              The set of features supported by the machine. Derivations
              can express dependencies on system features through the
              `requiredSystemFeatures` attribute.
            '';
          };

          allowed-users = lib.mkOption {
            type = with lib.types; listOf str;
            default = [ "*" ];
            example = [
              "@wheel"
              "@builders"
              "alice"
              "bob"
            ];
            description = ''
              A list of names of users (separated by whitespace) that are
              allowed to connect to the Nix daemon. As with
              {option}`nix.settings.trusted-users`, you can specify groups by
              prefixing them with `@`. Also, you can
              allow all users by specifying `*`. The
              default is `*`. Note that trusted users are
              always allowed to connect.
            '';
          };
        };
      };
      default = { };
      description = ''
        Configuration for Nix, see
        <https://nixos.org/manual/nix/stable/command-ref/conf-file.html> or
        {manpage}`nix.conf(5)` for available options.
        The value declared here will be translated directly to the key-value pairs Nix expects.

        You can use {command}`nix-instantiate --eval --strict '<nixpkgs/nixos>' -A config.nix.settings`
        to view the current value. By default it is empty.

        Nix configurations defined under {option}`nix.*` will be translated and applied to this
        option. In addition, configuration specified in {option}`nix.extraOptions` will be appended
        verbatim to the resulting config file.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc."nix/nix.conf".source = configFile;

    finit.services.nix-daemon = {
      description = "nix daemon";
      conditions = "service/syslogd/ready";
      command = "${cfg.package}/bin/nix-daemon --daemon";
      nohup = true;

      # https://github.com/NixOS/nix/blob/81884c36a381737a438ddc5decb658446074d064/misc/systemd/nix-daemon.service.in#L12-L13
      cgroup.settings."pids.max" = 1048576;
      rlimits.nofile = 1048576;
    };

    environment.systemPackages = [
      cfg.package
    ];

    services.tmpfiles.nix-daemon.rules = [
      "d /nix/var/nix/daemon-socket 0755 root root - -"

      "R! /nix/var/nix/gcroots/tmp           -    -    -    - -"
      "R! /nix/var/nix/temproots             -    -    -    - -"

      "d  /nix/var                           0755 root root - -"
      "L+ /nix/var/nix/gcroots/booted-system 0755 root root - /run/booted-system"

      # Prevent the current configuration from being garbage-collected.
      "d /nix/var/nix/gcroots -"
      "L+ /nix/var/nix/gcroots/current-system - - - - /run/current-system"
    ];

    synit.daemons.nix-daemon = {
      argv = [ "nix-daemon" "--daemon" ];
      path = [ pkgs.openssh cfg.package ];
    };

    users.users = lib.listToAttrs (map (nr: {
      name = "nixbld${toString nr}";
      value = {
        description = "Nix build user ${toString nr}";
        uid = builtins.add config.ids.uids.nixbld nr;
        group = "nixbld";
        extraGroups = [ "nixbld" ];
      };
    }) (lib.range 1 cfg.nrBuildUsers));

    users.groups = {
      nixbld.gid = config.ids.gids.nixbld;
    };

    services.nix-daemon.settings = {
      trusted-public-keys = [ "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" ];
      trusted-users = [ "root" ];
      substituters = lib.mkAfter [ "https://cache.nixos.org/" ];
      system-features = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
    };

    # TODO: add finit.services.restartTriggers option
    environment.etc."finit.d/nix-daemon.conf".text = lib.mkAfter ''

      # standard nixos trick to force a restart when something has changed
      # ${config.environment.etc."nix/nix.conf".source}
    '';
  };
}
