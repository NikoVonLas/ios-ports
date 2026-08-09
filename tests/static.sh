#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

for script in scripts/*.sh tests/*.sh; do
  bash -n "$script"
done

source config.env
[[ "$CODEX_REVISION" =~ ^[0-9a-f]{40}$ ]]
[[ "$IOS_TARGET" == "aarch64-apple-ios" ]]
[[ "$PACKAGE_ARCH" == "iphoneos-arm64" ]]
grep -q '^Package: com.openai.codex-ios$' packaging/control.in
grep -q '/var/jb/usr/bin/codex' scripts/package.sh
grep -q '^ldid -S/var/jb/usr/share/codex-ios/entitlements.plist' packaging/postinst

printf 'Static checks passed.\n'
