#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

for script in scripts/*.sh tests/*.sh; do
  bash -n "$script"
done

source config.env
[[ "$GH_CLI_LAST_RELEASE" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]
[[ "$GH_CLI_REVISION" =~ ^[0-9a-f]{40}$ ]]
[[ "$PACKAGE_ARCH" == iphoneos-arm64 ]]
grep -q '^Package: com.nikovonlas.github-cli-ios$' packaging/control.in
grep -q '^Provides: gh, github-cli$' packaging/control.in
grep -q '^Replaces: gh, github-cli$' packaging/control.in
grep -q 'export GOOS=ios' scripts/build.sh
grep -q 'export GOARCH=arm64' scripts/build.sh
grep -q -- '-buildmode=pie' scripts/build.sh
grep -q -- '-buildvcs=false' scripts/build.sh
grep -q 'internal/build.Version=' scripts/build.sh
grep -q '/var/jb/usr/bin/gh' scripts/package.sh
grep -q 'ldid -S/var/jb/usr/share/github-cli-ios/entitlements.plist' packaging/postinst
! grep -q 'com.apple.security.cs.allow-jit' packaging/entitlements.plist
! grep -q 'com.apple.security.cs.allow-unsigned-executable-memory' packaging/entitlements.plist
grep -q 'com.nikovonlas.github-cli-ios' ../codex/scripts/make-repo.py
grep -q 'ios-ports-upstream-update' ../../.github/workflows/github-cli-upstream.yml
grep -q 'actions/setup-go@v6' ../../.github/workflows/github-cli-upstream.yml
grep -q 'go_toolchain=' ../../.github/workflows/github-cli-upstream.yml
grep -q 'git diff --cached --quiet' ../../.github/workflows/github-cli-upstream.yml
grep -q '^Package: com.nikovonlas.github-cli-ios$' ../codex/docs/Packages
[[ "$(grep -c '^Package:' ../codex/docs/Packages)" -eq 3 ]]

tmp_config="$(mktemp)"
trap 'rm -f "$tmp_config"' EXIT
cp config.env "$tmp_config"
python3 scripts/update-upstream.py \
  --config "$tmp_config" \
  v123.45.6 \
  0123456789abcdef0123456789abcdef01234567
grep -q '^GH_CLI_LAST_RELEASE=v123.45.6$' "$tmp_config"
grep -q '^PACKAGE_VERSION=123.45.6$' "$tmp_config"
grep -q '^PACKAGE_REVISION=1$' "$tmp_config"
sed -i.bak 's/^PACKAGE_REVISION=1$/PACKAGE_REVISION=7/' "$tmp_config"
rm -f "$tmp_config.bak"
python3 scripts/update-upstream.py \
  --config "$tmp_config" \
  v123.45.6 \
  fedcba9876543210fedcba9876543210fedcba98
grep -q '^GH_CLI_REVISION=fedcba9876543210fedcba9876543210fedcba98$' "$tmp_config"
grep -q '^PACKAGE_REVISION=7$' "$tmp_config"

printf 'GitHub CLI static checks passed.\n'
