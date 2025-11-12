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
        suspend =
          lib.mapAttrs'
            (
              k: v:
              let
                name = "zzz.d/suspend/${zeroPad 4 v.priority}-${k}.sh";
              in
              lib.nameValuePair name {
                source = pkgs.writeShellScript k v.action;
              }
            )
            (lib.filterAttrs (_: v: v.enable && v.event == "suspend") config.providers.resumeAndSuspend.hooks);

        resume = lib.mapAttrs' (
          k: v:
          let
            name = "zzz.d/resume/${zeroPad 4 v.priority}-${k}.sh";
          in
          lib.nameValuePair name {
            source = pkgs.writeShellScript k v.action;
          }
        ) (lib.filterAttrs (_: v: v.enable && v.event == "resume") config.providers.resumeAndSuspend.hooks);
      in
      lib.mkMerge [
        suspend
        resume
      ];
  };
}
