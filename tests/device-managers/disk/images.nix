{ pkgs }:
let
  makeSet =
    hot:
    let
      tag = if hot then "hot" else "cold";
      prefix = if hot then "finix-hot" else "finix";
      uuidPrefix = if hot then "aaaaaaaa-bbbb-4ccc-8ddd" else "11111111-2222-4333-8444";
      make =
        name: metadata: tools: size: command:
        {
          inherit name;
          serial = "${tag}-${name}";
          fsType = null;
          partitioned = false;
          label = null;
          uuid = null;
          partitionUuid = null;
          partitionLabel = null;
          partitionNumber = null;
          diskUuid = null;
        }
        // metadata
        // {
          image =
            pkgs.runCommand "device-manager-${tag}-${name}.img"
              { nativeBuildInputs = [ pkgs.coreutils ] ++ tools; }
              ''
                truncate -s ${size} "$out"
                ${command metadata}
              '';
        };
    in
    {
      ext4 = make "ext4" {
        fsType = "ext4";
        label = "${prefix}-ext4";
        uuid = "${uuidPrefix}-eeeeeeeeeee1";
      } [ pkgs.e2fsprogs ] "32M" (m: ''mkfs.ext4 -q -F -L ${m.label} -U ${m.uuid} "$out"'');

      btrfs = make "btrfs" {
        fsType = "btrfs";
        label = "${prefix}-btrfs";
        uuid = "${uuidPrefix}-eeeeeeeeeee2";
      } [ pkgs.btrfs-progs ] "128M" (m: ''mkfs.btrfs -q -f -L ${m.label} -U ${m.uuid} "$out"'');

      vfat =
        make "vfat"
          {
            fsType = "vfat";
            label = if hot then "FINIXHVFAT" else "FINIXVFAT";
            uuid = if hot then "AABB-CCDD" else "1122-3344";
          }
          [ pkgs.dosfstools ]
          "32M"
          (
            m:
            ''mkfs.vfat --invariant -i ${builtins.replaceStrings [ "-" ] [ "" ] m.uuid} -n ${m.label} "$out"''
          );

      raw = make "raw" { } [ ] "32M" (_: "");

      gptExt4 =
        make "gpt-ext4"
          {
            fsType = "ext4";
            partitioned = true;
            label = if hot then "finix-hot-gpt" else "finix-gpt";
            uuid = "${uuidPrefix}-eeeeeeeeeee5";
            partitionUuid = "${uuidPrefix}-eeeeeeeeeee6";
            partitionLabel = "${prefix}-data";
            partitionNumber = 1;
            diskUuid = "${uuidPrefix}-eeeeeeeeeee7";
          }
          [ pkgs.e2fsprogs pkgs.util-linux ]
          "64M"
          (m: ''
            sfdisk "$out" <<EOF
            label: gpt
            label-id: ${m.diskUuid}
            start=2048, size=126976, type=linux, uuid=${m.partitionUuid}, name=${m.partitionLabel}
            EOF
            truncate -s 62M filesystem.img
            mkfs.ext4 -q -F -L ${m.label} -U ${m.uuid} filesystem.img
            dd if=filesystem.img of="$out" bs=1M seek=1 conv=notrunc status=none
          '');
    };
in
{
  cold = makeSet false;
  hot = makeSet true;
  order = [
    "ext4"
    "btrfs"
    "vfat"
    "raw"
    "gptExt4"
  ];
}
