#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/common.sh"

[[ -f "$UPSTREAM_DIR/go.mod" ]] || die "source is missing; run make fetch first"
grep -qx 'module github.com/cli/cli/v2' "$UPSTREAM_DIR/go.mod" || \
  die "unexpected upstream Go module"

sdk_path="$(xcrun --sdk iphoneos --show-sdk-path)"
clang="$(xcrun --sdk iphoneos --find clang)"
build_date="$(git -C "$UPSTREAM_DIR" show -s --format=%cs HEAD)"

rm -rf "$STAGE_DIR"
mkdir -p \
  "$STAGE_DIR/var/jb/usr/bin" \
  "$STAGE_DIR/var/jb/usr/share/doc/github-cli-ios"
install -m 0644 "$UPSTREAM_DIR/LICENSE" \
  "$STAGE_DIR/var/jb/usr/share/doc/github-cli-ios/LICENSE"

export GOOS=ios
export GOARCH=arm64
export CGO_ENABLED=1
export CC="$clang"
export CGO_CFLAGS="-isysroot $sdk_path -miphoneos-version-min=$IOS_DEPLOYMENT_TARGET"
export CGO_LDFLAGS="-isysroot $sdk_path -miphoneos-version-min=$IOS_DEPLOYMENT_TARGET"
export GOTOOLCHAIN=auto
export GOCACHE="$BUILD_ROOT/go-cache"

(
  cd "$UPSTREAM_DIR"
  go build \
    -buildmode=pie \
    -buildvcs=false \
    -trimpath \
    -ldflags="-s -w -buildid= -X github.com/cli/cli/v2/internal/build.Version=$PACKAGE_VERSION -X github.com/cli/cli/v2/internal/build.Date=$build_date" \
    -o "$STAGE_DIR/var/jb/usr/bin/gh" \
    ./cmd/gh
)

binary="$STAGE_DIR/var/jb/usr/bin/gh"
[[ -x "$binary" ]] || die "GitHub CLI binary was not produced"
if command -v ldid >/dev/null 2>&1; then
  ldid -S"$PROJECT_ROOT/packaging/entitlements.plist" "$binary"
fi
file "$binary"
