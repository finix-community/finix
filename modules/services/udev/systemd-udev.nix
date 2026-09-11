{ pkgs, ... }:
let
  systemd-udev =
    (pkgs.systemd.override {
      withAcl = false;
      withAnalyze = false;
      withApparmor = false;
      withAudit = false;
      withBootloader = false;
      withCompression = false;
      withCoredump = false;
      withCryptsetup = false;
      withRepart = false;
      withDocumentation = false;
      withFido2 = false;
      withFirstboot = false;
      withGcrypt = false;
      withHomed = false;
      withHostnamed = false;
      withImportd = false;
      withImds = false;
      withKmod = false;
      withLibidn2 = false;
      withLocaled = false;
      withLogind = false;
      withMachined = false;
      withNetworkd = false;
      withNspawn = false;
      withNss = false;
      withOomd = false;
      withOpenSSL = false;
      withPam = false;
      withPasswordQuality = false;
      withPCRE2 = false;
      withPolkit = false;
      withPortabled = false;
      withQrencode = false;
      withRemote = false;
      withResolved = false;
      withShellCompletions = false;
      withSysinstall = false;
      withSysusers = false;
      withSysupdate = false;
      withTimedated = false;
      withTimesyncd = false;
      withTpm2Tss = false;
      withUserDb = false;
      withVmspawn = false;
      withLibarchive = false;
      withVConsole = false;

      # pname is an argument in the original drv for some reason
      pname = "systemd-udev";
    }).overrideAttrs
      {
        postInstall = ''
          # remove some fluff
          rm -rf $out/etc
          rm -rf $out/share

          # remove everything but udev and hwdb
          find $out/lib -mindepth 1 -maxdepth 1 ! -name "udev" ! -name "systemd" ! -name "libudev.*" -exec rm -rf {} +
          find $out/lib/systemd -mindepth 1 -maxdepth 1 ! -name "libsystemd*" ! -name "systemd-udevd" -exec rm -rf {} +
          find $out/bin -mindepth 1 -maxdepth 1 ! -name "udevadm" ! -name "systemd-hwdb" -exec rm -rf {} +

          # remove udev rule requiring full systemd install
          rm $out/lib/udev/rules.d/99-systemd.rules
        '';
      };
in
systemd-udev
