{ config, lib, pkgs, ... }:
let
  inherit (config.security) wrappers;

  writeExeclineScript = pkgs.execline.passthru.writeScript;

  clientScript = writeExeclineScript "sudo.el" "-s0" ''
    importas -S $0
    backtick -E NAME ${pkgs.s6-portable-utils}/bin/s6-basename $0 ""
    ${pkgs.s6}/bin/s6-ipcclient /run/sudo/''${NAME}.sock
    ${pkgs.s6}/bin/s6-sudoc $@
  '';

  wrapperPkg = pkgs.runCommand "wrappers" { } ''
    mkdir -p $out/bin
    for prg in ${wrappers |> builtins.attrValues |> map (builtins.getAttr "program") |> toString}; do
      ln -s "${clientScript}" "$out/bin/$prg"
    done
  '';
in
{
  config = lib.mkIf (config.security.wrapperMethod == "s6-sudo") {

    environment.systemPackages = [ wrapperPkg ];

    security.wrapperDir = "${wrapperPkg}/bin";

    synit.milestones.wrappers = { };
    synit.daemons = wrappers |> lib.mapAttrs' (name: wrapper: {
      name = "sudo-${name}";
      value = {
        argv = [
          "if" "s6-mkdir" "-p" "/run/sudo" ""
          "s6-envuidgid" wrapper.owner
          "s6-ipcserver" "-v" "-U" "/run/sudo/${name}.sock"
          # TODO: rules on who can call this wrapper.
          "emptyenv"
          "s6-sudod"
          wrapper.source
        ];
        path = [ pkgs.s6 ];
        provides = [ [ "milestone" "wrappers" ] ];
        logging.enable = lib.mkDefault false;
      };
    });

    # Create a symlink at /run/wrappers/bin because that path is hardcoded within Nixpkgs.
    # Use s6-ln because it does atomic symlink replacement.
    system.activation.scripts.wrappers = {
      deps = [ "specialfs" ];
      text = ''
        ${pkgs.s6-portable-utils}/bin/s6-mkdir -p /run/wrappers
        ${pkgs.s6-portable-utils}/bin/s6-ln -s -f -n ${wrapperPkg}/bin /run/wrappers/bin
      '';
    };

  };
}

