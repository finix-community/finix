{
  config,
  lib,
  ...
}:
let
  cfg = config.programs.nix-channel;

  channels = [
    "https://channels.nixos.org/nixos-unstable nixos"
    "https://github.com/finix-community/finix/archive/main.tar.gz finix"
  ];
in
{
  options.programs.nix-channel = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [nix-channel](https://nixos.wiki/wiki/nix_channels).
      '';
    };
  };

  config = {
    environment.extraSetup = lib.optionalString (!cfg.enable) ''
      rm --force $out/bin/nix-channel
    '';

    finit.tmpfiles.rules = lib.optionals cfg.enable [
      ''f /root/.nix-channels - - - - ${lib.concatStringsSep "\\n" channels}\n''
    ];

    security.pam.environment = lib.optionalAttrs cfg.enable {
      NIX_PATH.default = [
        # channel aliases
        "nixpkgs=/nix/var/nix/profiles/per-user/root/channels/nixos"

        # instruct nixos-rebuild where configuration is located
        "nixos-config=/etc/nixos/configuration.nix"

        # combined list of channels
        "@{HOME}/.nix-defexpr/channels"
        "/nix/var/nix/profiles/per-user/root/channels"
      ];
    };
  };
}
