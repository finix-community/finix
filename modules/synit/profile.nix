{ lib, config, pkgs, ... }:

let
  cfg = config.synit.profile;

  inherit (lib)
    mkIf
    mkOption
    types
    ;

  preserves = pkgs.formats.preserves {
    ignoreNulls = true;
    rawStrings = true;
  };

  profileConfigFile =
    let drv = preserves.generate "profile.pr" cfg.config;
    in drv.overrideAttrs ({ ... }: {
      postBuild = ''
        # Assert that this profile has been loaded.
        hash=$(basename $out)
        echo "<synit-profile \"${config.networking.hostName}-''${hash:0:12}\" loaded>" >> $out
      '';
    });

  profileHash = with builtins; profileConfigFile
    |> toString |> baseNameOf |> substring 0 12;

in
{
  options = {
    synit.profile = {
      name = mkOption {
        description = ''
          A unique identifier for the Synit
          system configuration profile result.
        '';
        readOnly = true;
      };
      config = mkOption {
        description = ''
          The syndicate-server configuration that
          comprises a system configuration profile.
        '';
        # TODO: List of Preserves type.
      };
    };
  };

  config = mkIf config.synit.enable {
    synit.profile.name = "${config.networking.hostName}-${profileHash}";
    system.activation.scripts.synit-profile = {
      deps = [ "synit-config" ];
      text = ''
        mkdir -p /run/synit/config/profile/

        # Load the profile.
        echo '<synit-profile "${cfg.name}" load "${profileConfigFile}">' > /run/synit/config/profile/load-${profileHash}.pr

        # Activate the profile.
        echo '<synit-profile "${cfg.name}" activate>' >/run/synit/config/profile/activate-profile.pr
      '';
    };
  };
}
