#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

for script in scripts/*.sh tests/*.sh; do
  bash -n "$script"
done

source config.env
[[ "$CODEX_LAST_RELEASE" =~ ^rust-v[0-9]+\.[0-9]+\.[0-9]+$ ]]
[[ "$CODEX_REVISION" =~ ^[0-9a-f]{40}$ ]]
[[ "$IOS_TARGET" == "aarch64-apple-ios" ]]
[[ "$PACKAGE_ARCH" == "iphoneos-arm64" ]]
grep -q '^Package: com.nikovonlas.codex-ios$' packaging/control.in
grep -q '/var/jb/usr/bin/codex' scripts/package.sh
grep -q '/var/jb/usr/bin/codex-code-mode-host' scripts/package.sh
grep -q 'CODEX_ONLY_CODE_MODE_HOST' scripts/build.sh
grep -q 'V8_FROM_SOURCE:-1' scripts/build.sh
grep -q 'Let Cargo reconcile that local workspace metadata' scripts/build.sh
[[ "$(grep -c -- '--locked' scripts/build.sh)" -eq 2 ]]
grep -q 'cppgc_enable_caged_heap=false cppgc_enable_pointer_compression=false' scripts/build.sh
grep -q 'RUSTY_V8_SRC_BINDING_PATH' ../../.github/workflows/codex-upstream.yml
grep -q 'src_binding_nocage_release_aarch64-apple-ios.rs' ../../.github/workflows/codex-upstream.yml
grep -q "target_os = \\\"ios\\\"" patches/0003-disable-v8-sandbox-on-ios.patch
grep -q 'v8 = { workspace = true, features = \["v8_enable_sandbox"\] }' patches/0003-disable-v8-sandbox-on-ios.patch
grep -q '^ldid -S/var/jb/usr/share/codex-ios/entitlements.plist' packaging/postinst
grep -q "CONFIG\['PACKAGE_VERSION'\]" scripts/make-repo.py

tmp_config="$(mktemp)"
trap 'rm -f "$tmp_config"' EXIT
cp config.env "$tmp_config"
python3 scripts/update-upstream.py \
  --config "$tmp_config" \
  rust-v123.45.6 \
  0123456789abcdef0123456789abcdef01234567
grep -q '^CODEX_LAST_RELEASE=rust-v123.45.6$' "$tmp_config"
grep -q '^CODEX_REVISION=0123456789abcdef0123456789abcdef01234567$' "$tmp_config"
grep -q '^PACKAGE_VERSION=123.45.6$' "$tmp_config"
grep -q '^PACKAGE_REVISION=1$' "$tmp_config"

printf 'Static checks passed.\n'
