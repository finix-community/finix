#!/usr/bin/env bash

set -euo pipefail

# TODO:
shortRev="9db0ab9"

dry_run=0
force=0

# parse arguments
for arg in "$@"; do
  case "$arg" in
    --dry-run)
      dry_run=1
      ;;
    --force)
      force=1
      ;;
    *)
      echo "usage: $0 [--dry-run] [--force]" >&2
      exit 1
      ;;
  esac
done

echo "generating grub entries..."

src_dir="/nix/var/nix/profiles"
dest_dir="/boot/EFI/finix"
prefix="/boot"

if [ "$dry_run" -eq 0 ]; then
  mkdir -p "$dest_dir"
else
  echo "[dry-run] would ensure directory exists: $dest_dir"
fi

{
  first=true

  find "$src_dir" -maxdepth 1 -type l -name "system-*-link" 2>/dev/null | sort -Vr | while read -r profile; do
    target=$(readlink -f "$profile")

    if [ ! -d "$target" ]; then
      echo "warning: target is not a directory for $profile → $target" >&2
      continue
    fi

    dt=$(date -d @"$(stat --format %Y "$profile")" +'%Y%m%d @ %H%M%S')
    gen=$(basename "$profile" | awk -F'-' '{ print $2 }')

    initrd_link="$target/initrd"
    kernel_link="$target/kernel"

    if [ ! -L "$initrd_link" ]; then
      echo "warning: initrd is missing or not a symlink in $target" >&2
      continue
    fi

    if [ ! -L "$kernel_link" ]; then
      echo "warning: kernel is missing or not a symlink in $target" >&2
      continue
    fi

    real_initrd=$(readlink -f "$initrd_link")
    real_kernel=$(readlink -f "$kernel_link")

    nix_store_regex='^/nix/store/([^/]+)/([^/]+)$'

    if [[ "$real_initrd" =~ $nix_store_regex ]]; then
      initrd_name="${BASH_REMATCH[1]}-${BASH_REMATCH[2]}"
    else
      echo "warning: initrd path does not match expected pattern: $real_initrd" >&2
      continue
    fi

    if [[ "$real_kernel" =~ $nix_store_regex ]]; then
      kernel_name="${BASH_REMATCH[1]}-${BASH_REMATCH[2]}"
    else
      echo "warning: kernel path does not match expected pattern: $real_kernel" >&2
      continue
    fi

    initrd_dest="$dest_dir/$initrd_name"
    kernel_dest="$dest_dir/$kernel_name"

    # initrd
    if [ -e "$initrd_dest" ] && [ "$force" -eq 0 ]; then
      echo "info: skipping existing initrd file: $initrd_dest" >&2
    else
      if [ "$dry_run" -eq 0 ]; then
        tmp_initrd=$(mktemp "$dest_dir/$initrd_name.tmp.XXXXXX")
        cp "$real_initrd" "$tmp_initrd"
        mv -f "$tmp_initrd" "$initrd_dest"
        echo "copied: $real_initrd → $initrd_dest" >&2
      else
        echo "[dry-run] would copy $real_initrd → $initrd_dest" >&2
      fi
    fi

    # kernel
    if [ -e "$kernel_dest" ] && [ "$force" -eq 0 ]; then
      echo "info: skipping existing kernel file: $kernel_dest" >&2
    else
      if [ "$dry_run" -eq 0 ]; then
        tmp_kernel=$(mktemp "$dest_dir/$kernel_name.tmp.XXXXXX")
        cp "$real_kernel" "$tmp_kernel"
        mv -f "$tmp_kernel" "$kernel_dest"
        echo "copied: $real_kernel → $kernel_dest" >&2
      else
        echo "[dry-run] would copy $real_kernel → $kernel_dest" >&2
      fi
    fi

    if $first; then
      echo
      echo "menuentry \"finix - default\" {"
      echo "  linux ${kernel_dest/#$prefix} init=$target/init loglevel=1"
      echo "  initrd ${initrd_dest/#$prefix}"
      echo "}"

      echo
      echo "submenu \"finix - all configurations\" {"

      first=false
    fi

    echo
    echo "  menuentry \"finix generation $gen ${shortRev} - $dt\" {"
    echo "    linux ${kernel_dest/#$prefix} init=$target/init"
    echo "    initrd ${initrd_dest/#$prefix}"
    echo "  }"
  done

  echo
  echo "}"
} > /boot/grub/custom.cfg
