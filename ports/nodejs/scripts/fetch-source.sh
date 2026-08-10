#!/bin/sh
set -eu

# shellcheck disable=SC1091
. "$(dirname -- "$0")/common.sh"

downloads="$build_root/downloads"
mkdir -p "$downloads" "$build_root/src"

expected="$NODE_SHA256  $source_archive"

if [ -f "$source_archive" ]; then
  actual=$(shasum -a 256 "$source_archive" | awk '{print $1}')
  if [ "$actual" != "$NODE_SHA256" ]; then
    echo "error: existing archive has unexpected SHA-256" >&2
    echo "expected: $NODE_SHA256" >&2
    echo "actual:   $actual" >&2
    exit 1
  fi
else
  url="https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION.tar.xz"
  partial="$source_archive.partial"
  partial_sha=""
  if [ -f "$partial" ]; then
    partial_sha=$(shasum -a 256 "$partial" | awk '{print $1}')
  fi
  if [ "$partial_sha" != "$NODE_SHA256" ]; then
    rm -f "$partial"
    curl --fail --location --proto '=https' --tlsv1.2 \
      --retry 3 --output "$partial" "$url"
  fi
  actual=$(shasum -a 256 "$partial" | awk '{print $1}')
  if [ "$actual" != "$NODE_SHA256" ]; then
    echo "error: downloaded archive has unexpected SHA-256" >&2
    echo "expected: $NODE_SHA256" >&2
    echo "actual:   $actual" >&2
    exit 1
  fi
  mv "$partial" "$source_archive"
fi

if [ ! -f "$source_root/configure" ]; then
  rm -rf "$source_root"
  tar -C "$build_root/src" -xf "$source_archive"
fi

printf '%s\n' "$expected" > "$downloads/SHA256SUMS"
echo "source ready: $source_root"
