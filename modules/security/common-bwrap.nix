{
  config,
  pkgs,
  lib,

  extraFlags ? [ ],
  extraPaths ? [ ],
  ...
}: let
  bwrap = {
    base = extraFlags ++ [     
      "--unshare-all"
      "--die-with-parent"
      "--hostname sandbox"
      "--proc /proc"
      "--dev /dev"
      "--seccomp 10"
    ];

    roSys = extraPaths ++ [
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

        trap 'rm -rf "''$SANDBOX_RUN"' EXIT INT TERM

        BWRAP_ARGS="${lib.concatStringsSep " " (bwrap.base ++ bwrap.roSys)} --bind ''$SANDBOX_RUN /run --bind ''$SANDBOX_RUN /tmp"

        exec 10<"''${./common.bpf}"

        exec env -i \
            LANG="C.UTF-8" \
            PATH="/bin:/sbin" \
            bwrap ''$BWRAP_ARGS -- "''$@"
      '';
    };
  };
in
  bwrap // {
    override = args:
      import ./common-bwrap.nix {
        inherit
          config
          pkgs
          lib
          ;
          extraFlags = extraFlags ++ (args.extraFlags or [ ]);
          extraPaths = extraPaths ++ (args.extraPaths or [ ]);
      };
}
