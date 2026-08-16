{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.programs.modprobe;
in
{
  imports = [
    (lib.mkRenamedOptionModule
      [ "boot" "blacklistedKernelModules" ]
      [ "programs" "modprobe" "blacklist" ]
    )
    (lib.mkRenamedOptionModule [ "boot" "extraModprobeConfig" ] [ "programs" "modprobe" "extraConfig" ])
    (lib.mkRenamedOptionModule [ "boot" "modprobeConfig" "enable" ] [ "programs" "modprobe" "enable" ])
  ];

  options.programs.modprobe = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Whether to enable [modprobe](${pkgs.kmod.meta.homepage}).

        ::: {.note}
        This is useful for systems like containers which do not require a kernel.
        :::
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.kmod;
      defaultText = lib.literalExpression "pkgs.kmod";
      example = lib.literalExpression "pkgs.busybox";
      description = ''
        The package to use for `modprobe`.
      '';
    };

    blacklist = lib.mkOption {
      type =
        with lib.types;
        coercedTo (listOf str) (enabledList: lib.genAttrs enabledList (_attrName: true)) (attrsOf bool);
      default = { };
      example = [
        "cirrusfb"
        "i2c_piix4"
      ];
      description = ''
        Set of names of kernel modules that should not be loaded
        automatically by the hardware probing code. This can either be
        a list of modules or an attrset. In an attrset, names that are
        set to `true` represent modules that will be blacklisted.
      '';
      apply = modules: lib.attrNames (lib.filterAttrs (_: v: v) modules);
    };

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      example = ''
        options parport_pc io=0x378 irq=7 dma=1
      '';
      description = ''
        Any additional configuration to be appended to the generated
        {file}`modprobe.conf`.  This is typically used to
        specify module options.  See
        {manpage}`modprobe.d(5)` for details.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc."modprobe.d/ubuntu.conf".source = "${pkgs.kmod-blacklist-ubuntu}/modprobe.conf";
    environment.etc."modprobe.d/debian.conf".source = pkgs.kmod-debian-aliases;

    environment.etc."modprobe.d/00-nixos.conf".text = ''
      ${lib.flip lib.concatMapStrings cfg.blacklist (name: ''
        blacklist ${name}
      '')}

      ${cfg.extraConfig}
    '';

    environment.systemPackages = [
      cfg.package
    ];

    finit.tasks.modprobe = {
      command = pkgs.writeShellScript "load-kernel-modules" ''
        ${lib.getExe' cfg.package "modprobe"} -a ${lib.escapeShellArgs config.boot.kernelModules}
      '';
      runlevels = "S12345789";
      remain = true;
    };

    # TODO: can this be converted to a `finit.run` stanza to run in runlevel S? is that early enough?
    system.activation.scripts.modprobe = ''
      # Allow the kernel to find our wrapped modprobe (which searches
      # in the right location in the Nix store for kernel modules).
      # We need this when the kernel (or some module) auto-loads a
      # module.
      echo ${lib.getExe' cfg.package "modprobe"} > /proc/sys/kernel/modprobe
    '';
  };
}
