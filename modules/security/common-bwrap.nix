{
  config,
  pkgs,
  lib,
  ...
}: let
  bwrap = {
    base = [     
      "--unshare-all"
      "--die-with-parent"
      "--hostname sandbox"
      "--proc /proc"
      "--dev /dev"
      "--seccomp 10"
    ];

    roSys = [
      "--ro-bind /nix /nix"
      "--ro-bind /etc/resolv.conf /etc/resolv.conf"
    ] ++ (
      lib.forEach [
        "bin"
        "lib"
        "sbin"
        "etc"
        "share"
      ] (
        dir: 
          "--ro-bind ${config.environment.path}/${dir} /${dir}"
      )
    );

    trap = pkgs.writeShellApplication {
      name = "trap";
      runtimeInputs = with pkgs; [
        bubblewrap
        busybox
      ];

      text = ''
        
        SANDBOX_RUN=''$(mktemp -d /run/user/''$(id -u)/sandbox.XXXXXXXXXX)

        trap 'rm -rf "$SANDBOX_RUN"' EXIT INT TERM

        BWRAP_ARGS="${lib.concatStringsSep " " (bwrap.base ++ bwrap.roSys)} --bind $SANDBOX_RUN /run --bind $SANDBOX_RUN /tmp"

        exec 10<"${./common.bpf}"

        exec env -i \
            LANG="C.UTF-8" \
            PATH="/bin:/sbin" \
            bwrap ''$BWRAP_ARGS -- "''$@"
      '';
    };
  };
in
  bwrap.trap
