{ pkgs }:

pkgs.busybox.overrideAttrs (oldAttrs: {
  pname = "ash";
  configurePhase = ''
    runHook preConfigure
    make allnoconfig
    {
      echo "CONFIG_ASH=y"
      echo "CONFIG_ASH_ALIAS=y"
      echo "CONFIG_ASH_RANDOM_SUPPORT=y"
      echo "CONFIG_ASH_EXPAND_PRMT=y"
      echo "CONFIG_FEATURE_SH_EMBEDDED_SCRIPTS=n"
    } >> .config
    make oldconfig
    runHook postConfigure
  '';
  installPhase = ''
    runHook preInstall
    install -Dm755 busybox $out/bin/ash
    runHook postInstall
  '';
})
