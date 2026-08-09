#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

sdk_path="$(xcrun --sdk iphoneos --show-sdk-path)"
clang="$(xcrun --sdk iphoneos --find clang)"
clangxx="$(xcrun --sdk iphoneos --find clang++)"
target_key="$(printf '%s' "$IOS_TARGET" | tr '[:lower:]-' '[:upper:]_')"

export SDKROOT="$sdk_path"
export CARGO_TARGET_DIR="$TARGET_DIR"
export "CC_${IOS_TARGET//-/_}=$clang"
export "CXX_${IOS_TARGET//-/_}=$clangxx"
export "CARGO_TARGET_${target_key}_LINKER=$clang"
export CFLAGS="-isysroot $sdk_path -miphoneos-version-min=$IOS_DEPLOYMENT_TARGET"
export CXXFLAGS="$CFLAGS"
export RUSTFLAGS="-C link-arg=-isysroot -C link-arg=$sdk_path -C link-arg=-miphoneos-version-min=$IOS_DEPLOYMENT_TARGET"

cargo build \
  --manifest-path "$UPSTREAM_DIR/codex-rs/Cargo.toml" \
  --locked \
  --release \
  --target "$IOS_TARGET" \
  -p codex-cli \
  --bin codex

binary="$TARGET_DIR/$IOS_TARGET/release/codex"
[[ -x "$binary" ]] || die "Codex binary was not produced"
if command -v ldid >/dev/null 2>&1; then
  ldid -S"$PROJECT_ROOT/packaging/entitlements.plist" "$binary"
else
  printf 'warning: host ldid not found; binary will be signed by package postinst on iPad\n' >&2
fi
file "$binary"
