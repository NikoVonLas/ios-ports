#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

sdk_path="$(xcrun --sdk iphoneos --show-sdk-path)"
clang="$(xcrun --sdk iphoneos --find clang)"
clangxx="$(xcrun --sdk iphoneos --find clang++)"
ar="$(xcrun --sdk iphoneos --find ar)"
target_key="$(printf '%s' "$IOS_TARGET" | tr '[:lower:]-' '[:upper:]_')"
target_env="${IOS_TARGET//-/_}"

export SDKROOT="$sdk_path"
export CARGO_TARGET_DIR="$TARGET_DIR"
export "CC_${target_env}=$clang"
export "CXX_${target_env}=$clangxx"
export "AR_${target_env}=$ar"
export "CFLAGS_${target_env}=-isysroot $sdk_path -miphoneos-version-min=$IOS_DEPLOYMENT_TARGET"
export "CXXFLAGS_${target_env}=-isysroot $sdk_path -miphoneos-version-min=$IOS_DEPLOYMENT_TARGET"
export "CARGO_TARGET_${target_key}_LINKER=$clang"
export "CARGO_TARGET_${target_key}_RUSTFLAGS=-C link-arg=-isysroot -C link-arg=$sdk_path -C link-arg=-miphoneos-version-min=$IOS_DEPLOYMENT_TARGET"

only_code_mode_host="${CODEX_ONLY_CODE_MODE_HOST:-0}"

# Tagged Codex release commits can carry a Cargo.lock whose workspace package
# versions still read 0.0.0 after the release manifests have been stamped with
# the published version. Let Cargo reconcile that local workspace metadata
# while fetching dependencies, then keep every actual build locked.
cargo fetch \
  --manifest-path "$UPSTREAM_DIR/codex-rs/Cargo.toml" \
  --target "$IOS_TARGET"

if [[ "$only_code_mode_host" != 1 ]]; then
  cargo build \
    --manifest-path "$UPSTREAM_DIR/codex-rs/Cargo.toml" \
    --locked \
    --release \
    --target "$IOS_TARGET" \
    -p codex-cli \
    --bin codex
fi

# rusty_v8 does not publish a prebuilt archive for aarch64-apple-ios.
# Its source build automatically selects a jitless device configuration.
v8_from_source="${V8_FROM_SOURCE:-1}"
if [[ "$v8_from_source" == 1 ]]; then
  python3 "$PROJECT_ROOT/scripts/prepare-v8-source.py"
fi
# Oilpan's default 4 GiB caged heap is rejected by the iOS process address-space
# policy even when the main V8 sandbox is disabled.
v8_gn_args="${EXTRA_GN_ARGS:-}"
if [[ "$IOS_TARGET" == *-apple-ios ]]; then
  v8_gn_args="${v8_gn_args:+$v8_gn_args }cppgc_enable_caged_heap=false cppgc_enable_pointer_compression=false"
fi
EXTRA_GN_ARGS="$v8_gn_args" V8_FROM_SOURCE="$v8_from_source" cargo build \
  --manifest-path "$UPSTREAM_DIR/codex-rs/Cargo.toml" \
  --locked \
  --release \
  --target "$IOS_TARGET" \
  -p codex-code-mode-host \
  --bin codex-code-mode-host

binary="$TARGET_DIR/$IOS_TARGET/release/codex"
code_mode_host="$TARGET_DIR/$IOS_TARGET/release/codex-code-mode-host"
[[ -x "$code_mode_host" ]] || die "Codex Code Mode host was not produced"
if [[ "$only_code_mode_host" != 1 ]]; then
  [[ -x "$binary" ]] || die "Codex binary was not produced"
fi
if command -v ldid >/dev/null 2>&1; then
  if [[ "$only_code_mode_host" != 1 ]]; then
    ldid -S"$PROJECT_ROOT/packaging/entitlements.plist" "$binary"
  fi
  ldid -S"$PROJECT_ROOT/packaging/entitlements.plist" "$code_mode_host"
else
  printf 'warning: host ldid not found; binaries will be signed by package postinst on iPad\n' >&2
fi
if [[ "$only_code_mode_host" != 1 ]]; then
  file "$binary"
fi
file "$code_mode_host"
