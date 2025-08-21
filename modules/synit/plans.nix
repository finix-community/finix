{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.synit.plan;

  inherit (lib)
    attrValues
    concatLists
    mkDefault
    mkIf
    mkOption
    types
    ;

  preserves = pkgs.formats.preserves {
    ignoreNulls = true;
    rawStrings = true;
  };

in
{
  options = {
    synit.plan = {
      config = mkOption {
        description = ''
          The syndicate-server script that comprises
          a plan for system configuration.
        '';
        # TODO: Attrs of lists of Preserves type.
        type = with lib.types; anything |> listOf |> attrsOf;
      };
      file = mkOption {
        description = ''
          File containing the complete syndicate-server script for this plan.
        '';
        readOnly = true;
      };
      activatePlan = mkOption {
        description = ''
          Template for the activation script run by the user.
        '';
        type = types.package;
      };
    };
  };

  config = mkIf config.synit.enable {

    synit.plan = {

      activatePlan = pkgs.execline.passthru.writeScript "activatePlan.el" "-P" ''
        backtick -E HOSTNAME { s6-hostname }
        backtick -E PREFIX { s6-uniquename /run/synit/config/plans/$HOSTNAME }
        redirfd -w 1 ''${PREFIX}.pr
        s6-echo "! <activate <plan \"default\" \"${cfg.file}\" [ \"@systemConfig@/activate\" ]>>"
      '';

      file =
        cfg.config |> attrValues |> concatLists |>
        preserves.generate "${config.networking.hostName}.plan";
    };

  };
}
