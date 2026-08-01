#!/bin/sh
# POSIX compliant port of https://github.com/murdoa/finix-rk3506/blob/main/modules/setup-etc.sh
#
# Drop-in replacement for setup-etc.pl — eliminates perl (~51 MiB) from the
# system closure. Implements the same /etc/static symlink management logic.
#
# Deliberately avoids set -e: individual failures (stale symlinks, permission
# issues) should not abort the entire /etc setup.

etc="$1"
shift
static="/etc/static"

if [ -z "$etc" ]; then
  echo "setup-etc.sh: no etc path provided" >&2
  exit 1
fi

# Ensure /tmp exists for mktemp (specialfs activation runs after us).
mkdir -p /tmp

# Atomically update /etc/static to point at current configuration's etc.
ln -sfn "$etc" "$static"

# Remove dangling symlinks that point to a previous /etc/static.
find /etc -path /etc/nixos -prune -o -type l -print 2>/dev/null | while IFS= read -r link; do
  target="$(readlink "$link" 2>/dev/null)" || continue
  case "$target" in
  "$static"*)
    relative="${link#/etc/}"
    if [ ! -e "$static/$relative" ]; then
      echo "removing obsolete symlink '$link'..." >&2
      rm -f "$link"
    fi
    ;;
  esac
done

# Track copied files for cleanup across generations.
if [ -f /etc/.clean ]; then
  while IFS= read -r line; do
    set -- "$@" "$line"
  done </etc/.clean
fi

clean_tmp="$(mktemp)"
created_tmp="$(mktemp)"
etc_dirs="$(mktemp)"

find "$etc" -mindepth 1 >"$etc_dirs"

# For every file in the etc tree, create a corresponding symlink in /etc.
# Use process substitution to avoid subshell issues with pipes.
while IFS= read -r entry; do
  fn="${entry#"${etc}"/}"
  [ -n "$fn" ] || continue

  # Skip sidecar metadata files
  case "$fn" in
  *.mode | *.uid | *.gid) continue ;;
  esac

  target="/etc/$fn"
  echo "$fn" >>"$created_tmp"
  mkdir -p "$(dirname "$target")"

  # Skip directories
  if [ -d "$entry" ] && [ ! -L "$entry" ]; then
    continue
  fi

  if [ -f "$entry.mode" ]; then
    mode="$(cat "$entry.mode")"
    if [ "$mode" = "direct-symlink" ]; then
      src_store="$(readlink "$static/$fn" 2>/dev/null)" || true
      dst_store="$(readlink "$target" 2>/dev/null)" || true
      if [ ! -L "$target" ] || [ "$src_store" != "$dst_store" ]; then
        ln -sfn "$src_store" "$target"
      fi
    else
      uid="$(cat "$entry.uid" 2>/dev/null)" || uid="root"
      gid="$(cat "$entry.gid" 2>/dev/null)" || gid="root"
      cp "$static/$fn" "$target.tmp" 2>/dev/null || continue
      case "$uid" in
      +*) uid="${uid#+}" ;;
      *) uid="$(id -u "$uid" 2>/dev/null)" || uid=0 ;;
      esac
      case "$gid" in
      +*) gid="${gid#+}" ;;
      *) gid="$(getent group "$gid" 2>/dev/null | cut -d: -f3)" || gid=0 ;;
      esac
      chown "$uid:$gid" "$target.tmp" 2>/dev/null
      chmod "$mode" "$target.tmp" 2>/dev/null
      mv "$target.tmp" "$target" 2>/dev/null || rm -f "$target.tmp"
    fi
    echo "$fn" >>"$clean_tmp"
  elif [ -L "$entry" ]; then
    ln -sfn "$static/$fn" "$target"
  fi
done <"$etc_dirs"

# Delete files that were copied in a previous version but not in the current.
while [ "$#" != "0" ]; do
  if [ ! -n "$1" ]; then
    shift
    continue
  fi

  # dry running for testing
  if ! grep -qxF "$1" "$created_tmp" 2>/dev/null; then
    echo "removing obsolete file '/etc/$1'..." >&2
    rm -f "/etc/$1"
  fi
  shift
done

# Rewrite /etc/.clean
sort "$clean_tmp" >/etc/.clean 2>/dev/null || true
rm -f "$clean_tmp" "$created_tmp" "$etc_dirs"

# Create /etc/NIXOS tag
touch /etc/NIXOS
