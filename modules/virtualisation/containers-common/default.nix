{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.virtualisation.containers-common;
in
{
  options.virtualisation.containers-common = {

    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to enable [containers-common](https://github.com/podman-container-tools/container-libs) configuration, commonly used by `podman`, `buildah`, `cri-o` and `skopeo` .
      '';
    };

    containers = {
      settings = lib.mkOption {
        type = pkgs.formats.toml.type;
        default = { };
        description = ''
          containers.conf
          See [upstream documentation](https://github.com/podman-container-tools/container-libs/blob/main/common/docs/containers.conf.5.md).
        '';
      };
    };

    storage.settings = lib.mkOption {
      type = pkgs.formats.toml.type;
      default = {
        driver = lib.mkDefault "overlay";
        graphroot = lib.mkDefault "/var/lib/containers/storage";
        runroot = lib.mkDefault "/run/containers/storage";
      };
      description = ''
        storage.conf
        See [upstream documentation](https://github.com/podman-container-tools/container-libs/blob/main/storage/docs/containers-storage.conf.5.md).
      '';
    };

    registries.settings = lib.mkOption {
      type = pkgs.formats.toml.type;
      default = {
        unqualified-search-registries = [
          "docker.io"
          "quay.io"
        ];
      };
      example = lib.literalExpression ''
        {
          unqualified-search-registries = [
            "registry.com"
          ];

          registry = [
            {
              prefix = "example.com/foo";
              insecure = false;
              blocked = false;
              location = "internal-registry-for-example.com/bar";
              mirror = [
                {
                  location = "example-mirror-0.local/mirror-for-foo";
                }
                {
                  location = "example-mirror-1.local/mirrors/foo";
                  insecure = true;
                }
              ];
            }
          ];
        }
      '';
      description = ''
        registries.conf
        See [upstream documentation](https://github.com/podman-container-tools/container-libs/blob/main/image/docs/containers-registries.conf.5.md).
      '';
    };

    policy = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = ''
        policy.json
        See [upstream documentation](https://github.com/podman-container-tools/container-libs/blob/main/image/docs/containers-policy.json.5.md).
      '';
    };
  };

  config = lib.mkIf cfg.enable {

    environment.etc = with pkgs.formats; {
      "containers/containers.conf".source = toml.generate "containers.conf" cfg.containersConf.settings;
      "containers/storage.conf".source = toml.generate "storage.conf" cfg.storage.settings;
      "containers/registries.conf".source = toml.generate "registries.conf" cfg.registries;

      "containers/policy.json".source =
        if cfg.policy != { } then
          pkgs.writeText "policy.json" (builtins.toJSON cfg.policy)
        else
          "${pkgs.skopeo.policy}/default-policy.json";
    };

    finit.tmpfiles.rules = [
      "d /var/lib/containers 0755"
    ];
  };
}
