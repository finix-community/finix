{
  config,
  pkgs,
  lib,
  ...
}:
let
  empty = pkgs.writeText "no-inhibitors" "{}";

  checkSwitchInhibitors = pkgs.writeShellApplication {
    name = "check-switch-inhibitors";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      incoming="$1"

      exec >&2

      current_inhibitors="/run/current-system/switch-inhibitors"
      if [ ! -f "$current_inhibitors" ]; then
        current_inhibitors="${empty}"
      fi

      new_inhibitors="$incoming/switch-inhibitors"
      if [ ! -f "$new_inhibitors" ]; then
        new_inhibitors="${empty}"
      fi

      echo -n "checking switch inhibitors..."

      diff="$(
        jq \
          --raw-output \
          --null-input \
          --rawfile current "$current_inhibitors" \
          --rawfile newgen "$new_inhibitors" \
        '
          ($current | fromjson) as $old |
          ($newgen | fromjson) as $new |
          $old |
          to_entries |
          map(
            select(.key | in ($new)) |
            select(.value != $new.[.key]) |
            [ .key, ":", .value, "->", $new.[.key] ] | join(" ")
          ) |
          join("\n")
        ' \
      )"

      if [ -n "$diff" ]; then
        echo
        echo "there are changes to critical components of the system:"
        echo
        echo "$diff"
        echo
        echo "switching into this system is not recommended"
        echo "you probably want to run 'nixos-rebuild boot' and reboot your system instead"
        echo
        echo "if you really want to switch into this configuration directly, then"
        echo "you can set NIXOS_NO_CHECK=1 to ignore switch inhibitors"
        echo
        echo "WARNING: doing so might cause the switch to fail or your system to become unstable"
        echo

        exit 1
      else
        echo " done"
      fi
    '';
  };
in
{
  options.system.switch.inhibitors = lib.mkOption {
    type = with lib.types; attrsOf str;
    default = { };
    description = ''
      Attribute set of strings that will prevent switching into a configuration when
      they change.
      The switch can be manually forced on the command line if required.
    '';
  };

  config = {
    system.build.inhibitSwitch = pkgs.writers.writeJSON "switch-inhibitors" config.system.switch.inhibitors;
    system.build.checkSwitchInhibitors = lib.getExe checkSwitchInhibitors;
  };
}
