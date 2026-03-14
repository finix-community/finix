{
  config,
  pkgs,
  lib,
  ...
}:
let
  zeroPad =
    width: value:
    let
      s = toString value;
      padding = lib.concatStrings (builtins.genList (_: "0") (width - builtins.stringLength s));
    in
    padding + s;

  mkHook = mode: k: v:
    let
      name = "zzz.d/${zeroPad 4 v.priority}-${k}.sh";
      script = pkgs.writeShellScript k ''
        [ "''${ZZZ_MODE:-}" = "${mode}" ] || exit 0
        [ "$1" = "pre" ] || exit 0
        ${v.action}
      '';
    in
    lib.nameValuePair name { source = script; };

  mkResumeHook = k: v:
    let
      name = "zzz.d/${zeroPad 4 v.priority}-${k}.sh";
      script = pkgs.writeShellScript k ''
        [ "$1" = "post" ] || exit 0
        ${v.action}
      '';
    in
    lib.nameValuePair name { source = script; };
in
{
  options.providers.resumeAndSuspend = {
    backend = lib.mkOption {
      type = lib.types.enum [ "zzz" ];
    };
  };

  config = lib.mkIf (config.providers.resumeAndSuspend.backend == "zzz") {
    environment.etc =
      let
        filtered = event: lib.filterAttrs (_: v: v.enable && v.event == event) config.providers.resumeAndSuspend.hooks;

        suspend = lib.mapAttrs' (k: v: mkHook "suspend"  k v) (filtered "suspend");
        hibernate = lib.mapAttrs' (k: v: mkHook "hibernate"  k v) (filtered "hibernate");
        resume = lib.mapAttrs' (k: v: mkResumeHook k v) (filtered "resume");
      in
      lib.mkMerge [ suspend hibernate resume ];
  };
}
