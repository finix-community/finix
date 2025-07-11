# A Nixpkgs overlay to relieve packages from requiring udev
# at runtime. Modifications should minimize rebuilds by being
# made as close to the edge of a package closure as practical
# and should not affect anything that will be passed thru
# `nativeBuildInputs`.
#
# Boostrapping a stdenv without udev should be done elsewhere.
#

final: prev:
let
  udevZero = name: pkg: pkg
    |> ({ override, ... }: override { ${name} = final.libudev-zero; })
    |> ({ overrideAttrs, ... }: overrideAttrs { doCheck = false; });
in {
  libgudev = udevZero "udev" prev.libgudev;
  libinput = udevZero "udev" prev.libinput;
  niri = udevZero "eudev" prev.niri;
  umockdev = udevZero "systemdMinimal" prev.umockdev;
}
