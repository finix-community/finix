{ pkgs }:
let
  makeImage = name: size: mkfs: pkgs.runCommand "device-manager-${name}.img"
    { nativeBuildInputs = [ pkgs.coreutils ] ++ mkfs.nativeBuildInputs; }
    ''
      truncate -s ${size} "$out"
      ${mkfs.command} "$out"
    '';
in
{
  ext4 = {
    image = makeImage "ext4" "32M" {
      nativeBuildInputs = [ pkgs.e2fsprogs ];
      command = "mkfs.ext4 -q -F -L finix-ext4 -U 11111111-2222-3333-4444-555555555555";
    };
    label = "finix-ext4";
    uuid = "11111111-2222-3333-4444-555555555555";
  };
  btrfs = {
    image = makeImage "btrfs" "128M" {
      nativeBuildInputs = [ pkgs.btrfs-progs ];
      command = "mkfs.btrfs -q -f -L finix-btrfs -U 22222222-3333-4444-5555-666666666666";
    };
    label = "finix-btrfs";
    uuid = "22222222-3333-4444-5555-666666666666";
  };
  vfat = {
    image = makeImage "vfat" "32M" {
      nativeBuildInputs = [ pkgs.dosfstools ];
      command = "mkfs.vfat -n FINIXVFAT";
    };
    label = "FINIXVFAT";
    uuid = null;
  };
  raw = {
    image = pkgs.runCommand "device-manager-raw.img" { nativeBuildInputs = [ pkgs.coreutils ]; } ''
      truncate -s 32M "$out"
    '';
    label = null;
    uuid = null;
  };
}
