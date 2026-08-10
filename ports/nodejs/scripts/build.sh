#!/bin/sh
set -eu

# shellcheck disable=SC1091
. "$(dirname -- "$0")/common.sh"

"$project_root/scripts/check-toolchain.sh"

if [ ! -f "$source_root/configure" ]; then
  echo "error: source is missing; run make fetch first" >&2
  exit 1
fi

sdk_root=$(xcrun --sdk iphoneos --show-sdk-path)
host_sdk_root=$(xcrun --sdk macosx --show-sdk-path)
jobs=$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)

rm -rf "$stage_root"
mkdir -p "$stage_root"

cd "$source_root"
make distclean >/dev/null 2>&1 || true

export IOS_DEPLOYMENT_TARGET
export CC_host="$(xcrun -f clang)"
export CXX_host="$(xcrun -f clang++)"
export CFLAGS_host="-isysroot $host_sdk_root"
export CXXFLAGS_host="-isysroot $host_sdk_root -std=gnu++20"
export LDFLAGS_host="-isysroot $host_sdk_root"
export CC_target="$project_root/scripts/ios-clang"
export CXX_target="$project_root/scripts/ios-clang++"
export AR_target="$(xcrun --sdk iphoneos -f ar)"
export LD_target="$project_root/scripts/ios-clang++"
export NM_target="$(xcrun --sdk iphoneos -f nm)"
export RANLIB_target="$(xcrun --sdk iphoneos -f ranlib)"
export GYP_DEFINES="OS=ios target_arch=arm64 v8_target_arch=arm64 iphoneos_deployment_target=$IOS_DEPLOYMENT_TARGET"

./configure \
  --dest-os=ios \
  --dest-cpu=arm64 \
  --cross-compiling \
  --use_clang \
  --openssl-no-asm \
  --with-intl=small-icu \
  --prefix=/var/jb/usr

make -j"$jobs"
make install DESTDIR="$stage_root"

node_binary="$stage_root/var/jb/usr/bin/node"
if [ ! -f "$node_binary" ]; then
  echo "error: build completed without the expected node executable" >&2
  exit 1
fi

mkdir -p "$stage_root/var/jb/usr/lib/nodejs-ios24"
mv "$node_binary" "$stage_root/var/jb/usr/lib/nodejs-ios24/node-bin"
install -m 0755 "$project_root/packaging/node-wrapper" "$node_binary"

ldid_bin=${LDID:-ldid}
"$ldid_bin" -S"$project_root/packaging/entitlements.plist" \
  "$stage_root/var/jb/usr/lib/nodejs-ios24/node-bin"

install -d "$stage_root/var/jb/usr/share/nodejs-ios24"
install -m 0644 "$project_root/tests/smoke.js" \
  "$stage_root/var/jb/usr/share/nodejs-ios24/smoke.js"

echo "staged root: $stage_root"
