# Builds an ext2 image containing a populated /nix/store with the closure
# of store paths passed in the storePaths parameter, in addition to the
# contents of a directory that can be populated with commands. The
# generated image is sized to only fit its contents, with the expectation
# that a script resizes the filesystem at boot time.
{
  lib,
  stdenv,
  buildPackages,
  e2fsprogs,
  libfaketime,
  perl,
  fakeroot,
  qemu,
}:

{
  # List of derivations to be included.
  storePaths,
  # Output image format.
  format ? "raw",
  # Shell commands to populate the ./files directory.
  # All files in that directory are copied to the root of the FS.
  populateImageCommands ? "",
  volumeLabel,
}:
let
  fsClosureInfo = buildPackages.closureInfo { rootPaths = storePaths; };

  uuidFrom =
    seed:
    let
      digest = builtins.hashString "sha256" seed;
    in
    (lib.lists.foldl
      (
        { str, off }:
        n:
        let
          chunk = builtins.substring off n digest;
        in
        {
          str = if off == 0 then chunk else "${str}-${chunk}";
          off = off + n;
        }
      )
      {
        str = "";
        off = 0;
      }
      [
        8
        4
        4
        4
        12
      ]
    ).str;

  volumeUuid = uuidFrom fsClosureInfo.outPath;
in
stdenv.mkDerivation {
  name = "ext2-fs.img";

  nativeBuildInputs = [
    e2fsprogs.bin
    libfaketime
    perl
    fakeroot
  ]
  ++ lib.optional (format == "qcow2") qemu;

  buildCommand = ''
    img=temp.img
    (
    mkdir -p ./files
    ${populateImageCommands}
    )

    echo "Preparing store paths for image..."

    # Create nix/store before copying path
    mkdir -p ./rootImage/nix/store

    xargs -I % cp -a --reflink=auto % -t ./rootImage/nix/store/ < ${fsClosureInfo}/store-paths
    (
      GLOBIGNORE=".:.."
      shopt -u dotglob

      for f in ./files/*; do
          cp -a --reflink=auto -t ./rootImage/ "$f"
      done
    )

    # Also include a manifest of the closures in a format suitable for nix-store --load-db
    cp ${fsClosureInfo}/registration ./rootImage/nix-path-registration

    # Make a crude approximation of the size of the target image.
    # If the script starts failing, increase the fudge factors here.
    numInodes=$(find ./rootImage | wc -l)
    numDataBlocks=$(du -s -c -B 4096 --apparent-size ./rootImage | tail -1 | awk '{ print int($1 * 1.20) }')
    bytes=$((2 * 4096 * $numInodes + 4096 * $numDataBlocks))
    echo "Creating an EXT2 image of $bytes bytes (numInodes=$numInodes, numDataBlocks=$numDataBlocks)"

    mebibyte=$(( 1024 * 1024 ))
    # Round up to the nearest mebibyte.
    # This ensures whole 512 bytes sector sizes in the disk image
    # and helps towards aligning partitions optimally.
    if (( bytes % mebibyte )); then
      bytes=$(( ( bytes / mebibyte + 1) * mebibyte ))
    fi

    truncate -s $bytes $img

    faketime -f "1970-01-01 00:00:01" fakeroot mkfs.ext2 -L ${volumeLabel} -U ${volumeUuid} -d ./rootImage $img

    export EXT2FS_NO_MTAB_OK=yes
    # I have ended up with corrupted images sometimes, I suspect that happens when the build machine's disk gets full during the build.
    if ! fsck.ext2 -n -f $img; then
      echo "--- Fsck failed for EXT2 image of $bytes bytes (numInodes=$numInodes, numDataBlocks=$numDataBlocks) ---"
      cat errorlog
      return 1
    fi

    # We may want to shrink the file system and resize the image to
    # get rid of the unnecessary slack here--but see
    # https://github.com/NixOS/nixpkgs/issues/125121 for caveats.

    # shrink to fit
    resize2fs -M $img

    # Add 16 MebiByte to the current_size
    new_size=$(dumpe2fs -h $img | awk -F: \
      '/Block count/{count=$2} /Block size/{size=$2} END{print (count*size+16*2**20)/size}')

    resize2fs $img $new_size

    mkdir $out
    ${
      {
        raw = ''
          cp ./$img $out/image.raw
        '';
        qcow2 = ''
          qemu-img convert -f raw -O qcow2 ./$img $out/image.qcow2
          qemu-img resize -f qcow2 $out/image.qcow2 +2G
        '';
      }
      .${format}
    }
  '';
  passthru = {
    inherit volumeLabel volumeUuid;
  };
}
